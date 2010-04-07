require 'rubygems'
require 'sinatra'
require 'erb'

FONT_DIR = File.join(File.dirname(__FILE__),'public','fonts')

helpers do
  def font_dir(name, style = nil)
    if style
      File.join(FONT_DIR,name,style)
    else
      File.join(FONT_DIR,name)
    end
  end
  def valid_font?(name)
    File.exists?(font_dir(name))
  end
  def valid_font_style?(name, style)
    File.exists?(font_dir(name,style))
  end
  def all_fonts
    Dir.new(FONT_DIR).select { |dir| dir =~ /^[^\.]/ && File.directory?(File.join(FONT_DIR,dir)) }.sort
  end
  def font_styles(basename)
    $stderr.puts "looking for font dirs in #{font_dir(basename)}"
    results = Dir.new(font_dir(basename)).select { |dir| puts dir; dir =~ /^[^\.]/ && File.directory?(File.join(font_dir(basename),dir)) }.sort
    $stderr.puts "results: #{results.inspect}"
    results
  end
  def find_fontfile(path, extension)
    files = Dir.glob(path + "/*." + extension)
    raise "More than one #{extension} file in #{path}" if files.size > 1
    files.size == 0 ? nil : File.basename(files[0])
  end
  def single_font_css(name, path, prefix)
    $stderr.puts "producing css for '#{name}' in path #{path} with prefix #{prefix}"
    eot_file = find_fontfile(path,'eot')
    eot_css = eot_file ? "src: url('#{prefix}#{eot_file}');" : ''
    local_css = "local('no_such_local_name_we_hope')"
    woff_file = find_fontfile(path,'woff')
    woff_css = woff_file ? "url('#{prefix}#{woff_file}') format(\"woff\")" : ''
    otf_file = find_fontfile(path,'otf')
    otf_css = otf_file ? "url('#{prefix}#{otf_file}') format(\"opentype\")" : ''
    ttf_file = find_fontfile(path,'ttf')
    ttf_css = ttf_file ? "url('#{prefix}#{ttf_file}') format(\"truetype\")" : ''
    svg_file = find_fontfile(path,'svg')
    svg_suffix = name  # TODO: better svn id detection???
    svg_css = svg_file ? "url('#{prefix}#{svg_file}##{svg_suffix}') format(\"svg\")" : ''

    combo_css = [local_css,woff_css,otf_css,ttf_css,svg_css].reject{|txt| txt.empty?}.join(", ")
    css = <<-EOT
@font-face {
   font-family: '#{name}';
   #{eot_css}
   src: #{combo_css};
}
    EOT
  end

  def font_style_css(name, style)
    raise "Bad font name '#{name}' style '#{style}'" unless valid_font_style? name, style
    familyname = "#{name}#{style}"
    single_font_css(familyname, font_dir(name,style),"/fonts/#{name}/#{style}/")
  end

  def font_family_css(name)
    # returns the css for the fonts, plus a list of styles found
    raise "invalid font #{name}" unless valid_font? name
    all_css = single_font_css(name,font_dir(name),"/fonts/#{name}/") + "\n"
    styles = {}
    font_styles(name).each do |style|
      $stderr.puts "processing name #{name} style #{style}"
      familyname = "#{name}#{style}"
      all_css += font_style_css(name,style) + "\n"
      styles[style] = familyname
    end
    {:css => all_css, :styles => styles}
  end
end

get '/stylesheets/fonts/all.css' do
  content_type 'text/css', :charset => 'utf-8'
  all_fonts.collect {|font| font_family_css(font)[:css]}.join("\n")
end

get '/stylesheets/fonts/:basefont.css' do
  content_type 'text/css', :charset => 'utf-8'
  basefont = params[:basefont]
  raise "Bad font name '#{basefont}'" unless valid_font? basefont
  font_family_css(basefont)[:css]
end

get '/stylesheets/:basefont/details.css' do
  content_type 'text/css', :charset => 'utf-8'
  basefont = params[:basefont]
  raise "Bad font name '#{basefont}'" unless valid_font? basefont
  fontinfo = font_family_css(basefont)
  styles = fontinfo[:styles]
  output = "body, .typeface1 { font-family: \"#{basefont}\", Georgia; }\n"
  if styles['Italic']
    output += "body em, .typeface1 em { font-family: \"#{styles['Italic']}\", Georgia; }\n"
  end
  if styles['Bold']
    output += "body strong, .typeface1 strong { font-family: \"#{styles['Bold']}\", Georgia; }\n"
  end

  if styles['BoldItalic']
    output += "body strong em, .typeface1 strong em { font-family: \"#{styles['BoldItalic']}\", Georgia; }\n"
    output += "body em strong, .typeface1 em strong { font-family: \"#{styles['BoldItalic']}\", Georgia; }\n"
  end
  output += ".typeface2 { font-family: Verdana; }\n"
  output
end

get '/stylesheets/:basefont/:style/details.css' do
  content_type 'text/css', :charset => 'utf-8'
  basefont = params[:basefont]
  style = params[:style]
  raise "Bad font name '#{basefont}' style '#{style}'" unless valid_font_style? basefont, style
  fontinfo = font_family_css(basefont)
  stylefamily = fontinfo[:styles][style]
  output = "body, .typeface1 { font-family: \"#{stylefamily}\", Georgia; }\n"
  output += ".typeface2 { font-family: Verdana; }\n"
  output
end

get '/stylesheets/main_fonts.css' do
  content_type 'text/css', :charset => 'utf-8'
  output = ""
  all_fonts.each do |font|
    output += ".#{font} { font-family: \"#{font}\", Georgia; }\n"
    styles = font_family_css(font)[:styles]
    styles.values.each do |style|
      output += ".#{style} { font-family:\"#{style}\", Georgia; }\n"
    end
  end
  output
end

get '/' do
  fonts = []
  all_fonts.each do |font|
    styles = font_family_css(font)[:styles]
    children = styles.collect { |key, value| {:style => key, :family => value} }
    fonts << {:font => font, :children => children }
  end
  erb :index, :locals => {:fonts => fonts, :sample => "Handglove 123"}
end

get '/details/:basefont' do
  basefont = params[:basefont]
  raise "Bad font name '#{basefont}'" unless valid_font? basefont
  erb :details, :locals => {:basefont => basefont, :css_path => basefont, :fontname => basefont}
end

get '/details/:basefont/:style' do
  basefont = params[:basefont]
  style = params[:style]
  raise "Bad font name '#{basefont}' style '#{style}'" unless valid_font_style? basefont, style
  css_path = "#{basefont}/#{style}"
  fontname = "#{basefont} #{style}"
  erb :details, :locals => {:basefont => basefont, :css_path => css_path, :fontname => fontname}
end

