#!/usr/bin/ruby

# This function converts a single line of the markup format into the target
# format using the output filter 'o'.
#
# Bold and Italic are the only two things handled here since there are no other
# "inline" markups.
def convertInlineMarkup(string,o)
    i = 0
    inbold = false
    initalic = false
    output = ""
    while true
        pos = string.index('*',i)
        if !pos
            output += o.emit_text(string)
            break
        end
        if pos > 0 and string[(pos-1)..(pos-1)] == "\\"
            i = pos
            string = string[0..(pos-2)]+string[pos..-1]
            next
        end
        if string[(pos+1)..(pos+1)] == '*'
            output += o.emit_text(string[0..(pos-1)])
            output += inbold ? o.end_bold : o.start_bold
            inbold = !inbold
            i = 0
            string = string[(pos+2)..-1]
        else
            output += o.emit_text(string[0..(pos-1)])
            output += initalic ? o.end_italic : o.start_italic
            initalic = !initalic
            i = 0
            string = string[(pos+1)..-1]
        end
    end
    output += o.end_bold if inbold
    output += o.end_italic if initalic
    output
end

# Convert input into the target format using the 'o' output filter.
def convertSiboom(input,o)
    notes = []
    inparagraph = false
    inlist = false
    inpara = false
    output = o.header
    input = File.open(input).to_a if input.is_a?(String)
    i = 0

    # We perform processing on a line by line basis
    while input[i] do
        line = input[i]

        # Handle termination of lists/paragraphs.
        # To handle this here is much simpler.
        if inlist and line[0..2] != " * "
            output += o.end_list
            inlist = false
        end
        if (inpara and line[0..4] != "!note") and (line[0..2] == " * " or line[0..0] == "!" or line[0..0] == "=" or line.strip == "")
            output += o.end_para
            inpara = false
        end

        # Handle bang forms
        if line[0..0] == "!"
            ba = parseBangForm(input,i)
            case ba[0]
                when "book"
                    output += o.frontpage(ba[1].strip,ba[2].strip)
                when "image"
                    output += o.image(ba[1].strip,ba[2].strip)
                when "code"
                    output += o.code(ba[1..-1])
                when "cit"
                    output += o.cit(ba[1].strip,ba[2].strip)
                when "note"
                    notes << ba[1]
                    output += o.noteref(notes.length)
                when "shownotes"
                    if notes.length
                        output += o.title(ba[1].strip)
                        output += o.start_notes
                        notes.each_with_index{|n,notenum|
                            output += o.notes_item(notenum+1,convertInlineMarkup(n.strip,o))
                        }
                        output += o.end_notes
                    end
                else
                    raise "Unrecognized bang form: #{ba[0]} (line #{i})"
            end
            i += ba.length+1
            next
        end

        # Handle special forms like titles, subtitles, lists, ...
        if line[0..1] == "%%"
            # This is just a comment, skip it
            i += 1
            next
        elsif line[0..1] == "=="
            output += o.subtitle(line[2..-1].strip)
            i += 1
            next
        elsif line[0..0] == "="
            output += o.title(line[1..-1].strip)
            i += 1
            next
        elsif line[0..2] == " * "
            if !inlist
                inlist = true
                output += o.start_list
            end
            i += 1
            output += o.list_item(convertInlineMarkup(line[3..-1].strip,o))
            next
        end

        # Handle normal lines of text, with inline markup like bold and italic
        output += o.start_para if !inpara
        inpara = true
        output += convertInlineMarkup(line.strip,o)
        i += 1
    end

    # Done! Handle again the list termination thing
    output += o.end_list if inlist
    output += o.end_para if inpara
    output += o.footer
end

def parseBangForm(input,i)
    args = [input[i][1..-1].strip]
    i += 1
    while input[i][0..0] != "!"
        args << input[i]
        i += 1
    end
    args
end

################################ Output filters ################################

# HTML filter
class SiboomHtml
    def header
        '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">'+
        "<hmtl><head>"+
        '<link href="style.css" rel="stylesheet" type="text/css">'+
        "</head><body>\n"
    end

    def frontpage(title,author)
        "<h1>#{escape_html(title)}</h1>\n<address>#{escape_html(author)}<address>\n"
    end

    def title(text)
        "<h1>#{escape_html(text)}</h1>\n"
    end

    def subtitle(text)
        "<h2>#{escape_html(text)}</h2>\n"
    end

    def image(imgfile,descr)
        "<div class=\"image\"><img src=\"#{imgfile}\">"+
        "<br>#{descr}</div>\n"
    end

    def code(lines)
        "<pre class=\"code\">\n"+
        escape_html(lines.inject{|a,b| a+b})+
        "</pre>\n"
    end

    def noteref(notenum)
        "<a class=\"noteref\" href=\"#note#{notenum}\"><sup>#{notenum}</sup></a> "
    end

    def cit(cit,author)
        "<div class=\"citation\">#{cit}<br>"+
        "<address>-- #{author}</address></div>"
    end

    def start_para
        "\n<p>"
    end

    def end_para
        "</p>\n"
    end

    def emit_text(t)
        escape_html(t)
    end

    def start_list
        "\n<ul>\n"
    end

    def end_list
        "\n</ul>\n"
    end
    
    def list_item(item)
        "<li>#{item}</li>\n"
    end

    def start_notes
        "\n<ul>\n"
    end

    def end_notes
        "\n</ul>\n"
    end
    
    def notes_item(notenum,item)
        "<li><a name=\"note#{notenum}\">#{notenum}</a> #{item}</li>\n"
    end

    def start_bold
        "<b>"
    end

    def end_bold
        "</b>"
    end

    def start_italic
        "<i>"
    end

    def end_italic
        "</i>"
    end

    def footer
        "</body><html>\n"
    end

    def escape_html(s)
        s.gsub(/&/n, '&amp;').gsub(/\"/n, '&quot;').gsub(/>/n, '&gt;').gsub(/</n, '&lt;')
    end
end

# Plain text filter
class SiboomTxt
    def header
        ""
    end

    def frontpage(title,author)
        "#{title.upcase}\n#{author}\n\n"
    end

    def title(text)
        "\n#{text.upcase}\n\n"
    end

    def subtitle(text)
        "\n#{text}\n\n"
    end

    def image(imgfile,descr)
        "\n  (image: #{descr})\n\n"
    end

    def code(lines)
        "\n"+
        lines.map{|x| "    #{x}"}.inject{|a,b| a+b}+
        "\n"
    end

    def noteref(notenum)
        "[#{notenum}] "
    end

    def cit(cit,author)
        "\n  #{cit}"+
        "\n  -- #{author}\n\n"
    end

    def start_para
        ""
    end

    def end_para
        "\n"
    end

    def emit_text(t)
        if t.strip.length == 0
            ""
        else
            t
        end
    end

    def start_list
        "\n"
    end

    def end_list
        "\n"
    end

    def list_item(item)
        " * #{item}\n"
    end

    def start_notes
        "\n"
    end

    def end_notes
        "\n"
    end

    def notes_item(notenum,item)
        " [#{notenum}] #{item}\n"
    end

    def start_italic
        "_"
    end

    def end_italic
        "_"
    end

    def start_bold
        "*"
    end

    def end_bold
        "*"
    end
    
    def footer
        "\nEOF\n"
    end
end

if ARGV.length != 2
    puts "Usage: siboom <filename.siboom> [html|txt]"
    exit 1
end

case ARGV[1]
    when "html"
        filter = SiboomHtml.new
    when "txt"
        filter = SiboomTxt.new
    else
        puts "Unknown output filter: #{ARGV[1]}"
        exit 1
end
puts(convertSiboom(ARGV[0],filter))
