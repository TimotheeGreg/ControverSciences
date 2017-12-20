module LatexHelper

  class LaTeXRender < Redcarpet::Render::Base

    def normal_text(text)
      if text.length == 0
        ''
      else
        text
      end
    end

    def link(link, title, content)
      if content[0] == "*"
        ''
      else
        content
      end
    end

    def codespan(code)
      "\\begin{verbatim} \r #{normal_text(code)} \r \\end{verbatim}"
    end

    def header(title, heading)
      "\\large #{title}"  + "\\normalsize \\\\\n"
    end

    def superscript(text)
      if text[0] == "_"
        "$_{#{text[1..-1]}}"
      else
        "$^{#{text}}"
      end
    end

    def paragraph(text)
      text + " \\\\ \n\n"
    end

    def double_emphasis(text)
      "\\textbf{#{text}}"
    end

    def emphasis(text)
      "\\textit{#{text}}"
    end

    def list(content, list_type)
      head = "\\vspace{-.5em}"
      itemsep = " \\setlength\\itemsep{0em} \n"
      case list_type
        when :ordered
          head + "\\begin{enumerate}#{itemsep}#{content}\\end{enumerate} \n\n"
        when :unordered
          head + "\\begin{itemize}#{itemsep}#{content}\\end{itemize} \n\n"
      end
    end

    def list_item(content, list_type)
      "\\item #{content.strip} \n"
    end
  end

  def lesc(text, section=false)
    renderer = LaTeXRender.new
    extensions = {
        lax_spacing: true,
        strikethrough: true,
        superscript: true
    }
    redcarpet = Redcarpet::Markdown.new(renderer, extensions)
    latexstr = redcarpet.render(text)

    escape_re = /([_$&%#^])/
    latexstr.gsub!(escape_re) {|m| "\\#{m}"}
    latexstr.sub!("~", "$\\sim$")
    if section
      latexstr[0..-6].html_safe
    else
      latexstr.html_safe
    end
  end

  def render_to_pdf(model, text, list)
    @text = text
    unless @text.strip.blank?
      begin
        render_to_string(:template => 'assistant/partial_tex.pdf.erb', :layout => true)
      rescue Exception => exp
        file = exp.to_s[('rails-latex failed: See '.length)..-(' for details'.length+1)]
        log = File.open(file).read[24020..-1]
        list.append([model, log, text])
      end
    end
  end

end