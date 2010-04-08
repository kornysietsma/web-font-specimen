require 'rubygems'
require 'sinatra'
require 'erb'
require 'lib/fontinfo'

FONT_DIR = File.join(File.dirname(__FILE__),'public','fonts')

[:eot, :woff, :ttf, :otf ].each do |ext|
  mime_type ext, 'application/octet-stream'
end
mime_type :svg, 'image/svg+xml'

helpers do
  def fonts
    # cache just in case - though it'll be re-generated on each request, of course:
    @fonts ||= FontDir.new(FONT_DIR,"")
  end
end

get '/stylesheets/fonts/all.css' do
  content_type 'text/css', :charset => 'utf-8'
  fonts.all_css
end

get %r{/stylesheets/fonts/([\w_\-/]+).css} do
  content_type 'text/css', :charset => 'utf-8'
  font_path = params[:captures].first
  fonts.font_by_path(font_path).all_css
end

get %r{/stylesheets/details/([\w_\-/]+).css} do
  content_type 'text/css', :charset => 'utf-8'
  font_path = params[:captures].first
  font = fonts.font_by_path(font_path)
  output = "body, .typeface1 { font-family: \"#{font.familyname}\", Georgia; }\n"
  if font.basefont?
    italic_style = font.styles.keys.detect {|style| style.downcase == 'italic'}
    if italic_style
      output += "body em, .typeface1 em { font-family: \"#{font.styles[italic_style].familyname}\", Georgia; }\n"
    end
    bold_style = font.styles.keys.detect {|style| style.downcase == 'bold'}
    if bold_style
      output += "body strong, .typeface1 strong { font-family: \"#{font.styles[bold_style].familyname}\", Georgia; }\n"
    end
    bi_style = font.styles.keys.detect {|style| /bold.?italic/ =~ style.downcase }
    if bi_style
      output += "body strong em, .typeface1 strong em { font-family: \"#{font.styles[bi_style].familyname}\", Georgia; }\n"
      output += "body em strong, .typeface1 em strong { font-family: \"#{font.styles[bi_style].familyname}\", Georgia; }\n"
    end
  end
  output += ".typeface2 { font-family: Verdana; }\n"
  output
end

get '/stylesheets/main_fonts.css' do
  content_type 'text/css', :charset => 'utf-8'
  fonts.all_families.collect do |family|
    ".#{family} { font-family: \"#{family}\", Georgia; }\n"
  end.join("\n")
end

get '/' do
  erb :index, :locals => {:fonts => fonts}
end

get %r{/details/([\w_\-/]+)} do
  font_path = params[:captures].first
  font = fonts.font_by_path(font_path)
  erb :details, :locals => {:basefont => font.familyname, :css_path => font.url_base, :fontname => font.familyname}
end

