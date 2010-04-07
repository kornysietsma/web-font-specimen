require 'rubygems'
require 'sinatra'
require 'erb'
require 'lib/fontinfo'

FONT_DIR = File.join(File.dirname(__FILE__),'public','fonts')

helpers do
  def fonts
    # cache just in case - though it'll be re-generated on each request, of course:
    @fonts ||= FontDir.new(FONT_DIR,"/")
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
    if font.styles['Italic']
      output += "body em, .typeface1 em { font-family: \"#{font.styles['Italic'].familyname}\", Georgia; }\n"
    end
    if font.styles['Bold']
      output += "body strong, .typeface1 strong { font-family: \"#{font.styles['Bold'].familyname}\", Georgia; }\n"
    end
    if font.styles['BoldItalic']
      output += "body strong em, .typeface1 strong em { font-family: \"#{font.styles['BoldItalic'].familyname}\", Georgia; }\n"
      output += "body em strong, .typeface1 em strong { font-family: \"#{font.styles['BoldItalic'].familyname}\", Georgia; }\n"
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
  erb :index, :locals => {:fonts => fonts, :sample => "Handglove 123"}
end

get %r{/details/([\w_\-/]+)} do
  $stderr.puts params.inspect
  font_path = params[:captures].first
  font = fonts.font_by_path(font_path)
  erb :details, :locals => {:basefont => font.familyname, :css_path => font.url_base[0..-2], :fontname => font.familyname}
end

