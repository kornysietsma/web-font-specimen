class FontDir
  FONT_FILE_PATTERN = "*.{eot,woff,ttf,otf}"
  attr_accessor :name
  def initialize(font_path, url_base, name = nil)
    @name = name  # the name of the path under it's parent, or nil for the root
    @font_path = font_path
    @url_base = url_base
    @children = []  # FontDir entries for child directories
    @fonts = [] # Font entries for direct child fonts
    find_children
  end
  
  def find_children
    Dir.new(@font_path).each do |filename|
      next if filename =~ /\.\.?/
      child_path = File.join(@font_path, filename)
      next unless File.directory? child_path
      child_url = @url_base == '' ? filename : "#{@url_base}/#{filename}"
      unless Dir.glob(File.join(child_path,FONT_FILE_PATTERN)).empty?
        @fonts << Font.new(child_path, child_url, filename)
      else
        child = FontDir.new(child_path, child_url, filename)
        @children << child unless child.empty?
      end
    end
  end
  def empty?
    @fonts.empty? && @children.empty?
  end
  def all_css
    @fonts.collect {|font| font.all_css}.join("\n") + \
      @children.collect {|child| child.all_css}.join("\n")
  end
  def all_families
    (@fonts.collect {|font| font.all_families} + \
      @children.collect {|child| child.all_families}).flatten
  end
  def font_by_path(subpath)
    # note subpath starts with no '/', and it's a child of current path
    first, rest = subpath.split('/',2)
    if rest
      font_match = @fonts.detect {|font| font.family == first}
      return font_match.style_by_path(rest) if font_match
      dir_match = @children.detect {|child| child.name == first}
      raise "can't find valid #{first} under #{@font_path}" unless dir_match
      return dir_match.font_by_path(rest)
    else
      font_match = @fonts.detect {|font| font.family == first}
      raise "can't find font #{first} under #{@font_path}" unless font_match
      return font_match
    end
  end

  def html_index
    # Render the html snippet for the index page
    # This would be better in the index.erb file
    #   - but nesting erb templates got beyond me, so it's here.
    # assumes we are inside a <ul> node
    @children.collect {|child| "<li>\n#{child.name} :<ul>\n" + child.html_index + "</ul>\n</li>\n"}.join + \
      @fonts.collect {|font| "<li>\n" + font.html_index + "</li>\n"}.join
  end
end

class Font
  attr_accessor :styles, :style, :family, :url_base
  def initialize(font_path, url_base, family, style = nil)
    raise "Invalid Font directory #{font_path}" if Dir.glob(File.join(font_path,FontDir::FONT_FILE_PATTERN)).empty?
    @font_path = font_path
    @url_base = url_base
    @family = family
    @style = style
    @styles = style.nil? ? find_styles : {}
  end
  def basefont?
    @style.nil?
  end
  def familyname
    @family + (@style || '')
  end
  def find_styles
    styles = {}
    Dir.new(@font_path).each do |filename|
      next if filename =~ /\.\.?/
      child_path = File.join(@font_path, filename)
      next unless File.directory? child_path
      child_url = "#{@url_base}/#{filename}"
      if !Dir.glob(File.join(child_path,FontDir::FONT_FILE_PATTERN)).empty?
        styles[filename] = Font.new(child_path, child_url, @family, filename)
      # no 'else' - if it's not a font dir, we look no deeper
      end
    end
    styles
  end
  def self.find_fontfile(path, extension)
    files = Dir.glob(path + "/*." + extension)
    raise "More than one #{extension} file in #{path}" if files.size > 1
    files.size == 0 ? nil : File.basename(files[0])
  end
  def css
    eot_file = Font.find_fontfile(@font_path,'eot')
    eot_css = eot_file ? "src: url('/fonts/#{@url_base}/#{eot_file}');" : ''
    local_css = "local('#{familyname}')"
    woff_file = Font.find_fontfile(@font_path,'woff')
    woff_css = woff_file ? "url('/fonts/#{@url_base}/#{woff_file}') format(\"woff\")" : ''
    otf_file = Font.find_fontfile(@font_path,'otf')
    otf_css = otf_file ? "url('/fonts/#{@url_base}/#{otf_file}') format(\"opentype\")" : ''
    ttf_file = Font.find_fontfile(@font_path,'ttf')
    ttf_css = ttf_file ? "url('/fonts/#{@url_base}/#{ttf_file}') format(\"truetype\")" : ''
    svg_file = Font.find_fontfile(@font_path,'svg')
    svg_suffix = familyname  # TODO: better svn id detection???
    svg_css = svg_file ? "url('/fonts/#{@url_base}/#{svg_file}##{svg_suffix}') format(\"svg\")" : ''

    combo_css = [local_css,woff_css,otf_css,ttf_css,svg_css].reject{|txt| txt.empty?}.join(", ")
    <<-EOT
@font-face {
   font-family: '#{familyname}';
   #{eot_css}
   src: #{combo_css};
}
    EOT
  end
  def all_css
    css + "\n" + @styles.values.collect {|style| style.css}.join("\n")
  end
  def style_by_path(name)
    raise "No valid style #{style} in #{@font_path}" unless @styles.has_key? name
    @styles[name]
  end
  def all_families
    if basefont?
      [familyname] + @styles.values.collect {|style| style.familyname}
    else
      [familyname]
    end
  end
  def own_html_index
    %Q{<a href="/details/#{@url_base}">#{familyname} : <span class="#{familyname}">Lorem Ipsum</span></a>\n}
  end
  def html_index
    # assume inside a parent's li element
    if !basefont?
      own_html_index
    else
      child_html = @styles.empty? ? "" : "<ul>\n" + @styles.values.collect{|style| "<li>" + style.html_index + "</li>"}.join("\n") + "\n</ul>\n"
      own_html_index + child_html
    end
  end
end
