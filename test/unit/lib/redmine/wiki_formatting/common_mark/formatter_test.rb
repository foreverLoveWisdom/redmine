# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative '../../../../../test_helper'

class Redmine::WikiFormatting::CommonMark::FormatterTest < ActionView::TestCase
  if Object.const_defined?(:Commonmarker)

    def setup
      @formatter = Redmine::WikiFormatting::CommonMark::Formatter
    end

    def to_html(text)
      @formatter.new(text).to_html
    end

    def test_should_render_hard_breaks
      html ="<p>foo<br>\nbar</p>"
      assert_equal html, to_html("foo\\\nbar")
      assert_equal html, to_html("foo  \nbar")
    end

    def test_should_render_soft_breaks
      assert_equal "<p>foo<br>\nbar</p>", to_html("foo\nbar")
    end

    def test_syntax_error_in_image_reference_should_not_raise_exception
      assert to_html("!>[](foo.png)")
    end

    def test_empty_image_should_not_raise_exception
      assert to_html("![]()")
    end

    def test_inline_style
      assert_equal "<p><strong>foo</strong></p>", to_html("**foo**")
    end

    def test_not_set_intra_emphasis
      assert_equal "<p>foo_bar_baz</p>", to_html("foo_bar_baz")
    end

    def test_wiki_links_should_be_preserved
      text = 'This is a wiki link: [[Foo]]'
      assert_include '[[Foo]]', to_html(text)
    end

    def test_redmine_links_with_double_quotes_should_be_preserved
      text = 'This is a redmine link: version:"1.0"'
      assert_include 'version:"1.0"', to_html(text)
    end

    def test_links_by_id_should_be_preserved
      text = "[project#3]"
      assert_equal "<p>#{text}</p>", to_html(text)
    end

    def test_links_to_users_should_be_preserved
      text = "[@login]"
      assert_equal "<p>#{text}</p>", to_html(text)
      text = "[user:login]"
      assert_equal "<p>#{text}</p>", to_html(text)
      text = "user:user@example.org"
      assert_equal "<p>#{text}</p>", to_html(text)
      text = "[user:user@example.org]"
      assert_equal "<p>#{text}</p>", to_html(text)
      text = "@user@example.org"
      assert_equal "<p>#{text}</p>", to_html(text)
      text = "[@user@example.org]"
      assert_equal "<p>#{text}</p>", to_html(text)
    end

    def test_files_with_at_should_not_end_up_as_mailto_links
      text = "printscreen@2x.png"
      assert_equal "<p>#{text}</p>", to_html(text)
      text = "[printscreen@2x.png]"
      assert_equal "<p>#{text}</p>", to_html(text)
    end

    def test_should_support_syntax_highlight
      text = <<~STR
        ~~~ruby
        def foo
        end
        ~~~
      STR
      assert_select_in to_html(text), 'pre code.ruby.syntaxhl' do
        assert_select 'span.k', :text => 'def'
        assert_select "[data-language='ruby']"
      end
    end

    def test_should_support_syntax_highlight_for_language_with_special_chars
      text = <<~STR
        ~~~c++
        int main() {
        }
        ~~~
      STR

      assert_select_in to_html(text), 'pre' do
        assert_select 'code[class=?]', "c++ syntaxhl"
        assert_select 'span.kt', :text => 'int'
        assert_select "[data-language=?]", "c++"
      end
    end

    def test_external_links_should_have_external_css_class
      text = 'This is a [link](http://example.net/)'
      assert_equal '<p>This is a <a href="http://example.net/" class="external">link</a></p>', to_html(text)
    end

    def test_locals_links_should_not_have_external_css_class
      text = 'This is a [link](/issues)'
      assert_equal '<p>This is a <a href="/issues">link</a></p>', to_html(text)
    end

    def test_markdown_should_not_require_surrounded_empty_line
      text = <<-STR
  This is a list:
  * One
  * Two
      STR
      assert_equal "<p>This is a list:</p>\n<ul>\n<li>One</li>\n<li>Two</li>\n</ul>", to_html(text)
    end

    def test_footnotes
      text = <<~STR
        This is some text[^1].

        [^1]: This is the foot note
      STR

      expected = <<~EXPECTED
        <p>This is some text<sup><a href="#fn-1" id="fnref-1">1</a></sup>.</p>
         <ol>
        <li id="fn-1">
        <p>This is the foot note <a href="#fnref-1" aria-label="Back to reference 1">↩</a></p>
        </li>
        </ol>
      EXPECTED

      assert_equal expected.gsub(%r{[\r\n\t]}, ''), to_html(text).gsub(%r{[\r\n\t]}, '').rstrip
    end

    STR_WITH_PRE = [
      # 0
      <<~STR.chomp,
        # Title

        Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Maecenas sed libero.
      STR
      # 1
      <<~STR.chomp,
        ## Heading 2

        ~~~ruby
          def foo
          end
        ~~~

        Morbi facilisis accumsan orci non pharetra.

        ~~~ ruby
        def foo
        end
        ~~~

        ```
        Pre Content:

        ## Inside pre

        <tag> inside pre block

        Morbi facilisis accumsan orci non pharetra.
        ```
      STR
      # 2
      <<~STR.chomp,
        ### Heading 3

        Nulla nunc nisi, egestas in ornare vel, posuere ac libero.
      STR
    ]

    def test_get_section_should_ignore_pre_content
      text = STR_WITH_PRE.join("\n\n")

      assert_section_with_hash STR_WITH_PRE[1..2].join("\n\n"), text, 2
      assert_section_with_hash STR_WITH_PRE[2], text, 3
    end

    def test_get_section_should_not_recognize_double_hash_issue_reference_as_heading
      text = <<~STR
        ## Section A

        This text is a part of Section A.

        ##1 : This is an issue reference, not an ATX heading.

        This text is also a part of Section A.
        <!-- Section A ends here -->
      STR

      assert_section_with_hash text.chomp, text, 1
    end

    def test_update_section_should_not_escape_pre_content_outside_section
      text = STR_WITH_PRE.join("\n\n")
      replacement = "New text"

      assert_equal [STR_WITH_PRE[0..1], "New text"].join("\n\n"),
        @formatter.new(text).update_section(3, replacement)
    end

    def test_should_emphasize_text
      text = 'This _text_ should be emphasized'
      assert_equal '<p>This <em>text</em> should be emphasized</p>', to_html(text)
    end

    def test_should_strike_through_text
      text = 'This ~~text~~ should be striked through'
      assert_equal '<p>This <del>text</del> should be striked through</p>', to_html(text)
    end

    def test_should_autolink_urls_and_emails
      [
        ["http://example.org", '<p><a href="http://example.org" class="external">http://example.org</a></p>'],
        ["http://www.redmine.org/projects/redmine/issues?utf8=✓",
         '<p><a href="http://www.redmine.org/projects/redmine/issues?utf8=%E2%9C%93" class="external">http://www.redmine.org/projects/redmine/issues?utf8=✓</a></p>'],
        ['[Letters](https://yandex.ru/search/?text=кол-во)', '<p><a href="https://yandex.ru/search/?text=%D0%BA%D0%BE%D0%BB-%D0%B2%D0%BE" class="external">Letters</a></p>'],
        ["www.example.org", '<p><a href="http://www.example.org" class="external">www.example.org</a></p>'],
        ["user@example.org", '<p><a href="mailto:user@example.org" class="email">user@example.org</a></p>']
      ].each do |text, html|
        assert_equal html, to_html(text)
      end
    end

    def test_should_support_html_tables
      text = '<table style="background: red"><tr><td>Cell</td></tr></table>'
      assert_equal '<table><tr><td>Cell</td></tr></table>', to_html(text)
    end

    def test_should_remove_unsafe_uris
      [
        ['<img src="data:foobar">', '<img>'],
        ['<a href="javascript:bla">click me</a>', '<p><a>click me</a></p>'],
      ].each do |text, html|
        assert_equal html, to_html(text)
      end
    end

    def test_should_escape_unwanted_tags
      [
        [
          %[<p>sit<br>amet &lt;style&gt;.foo { color: #fff; }&lt;/style&gt; &lt;script&gt;alert("hello world");&lt;/script&gt;</p>],
          %[sit<br/>amet <style>.foo { color: #fff; }</style> <script>alert("hello world");</script>]
        ]
      ].each do |expected, input|
        assert_equal expected, to_html(input)
      end
    end

    def test_should_support_task_list
      text = <<~STR
        Task list:
        * [ ] Task 1
        * [x] Task 2
      STR

      expected = <<~EXPECTED
        <p>Task list:</p>
        <ul class="contains-task-list">
        <li class="task-list-item">
        <input type="checkbox" class="task-list-item-checkbox" disabled> Task 1
        </li>
        <li class="task-list-item">
        <input type="checkbox" class="task-list-item-checkbox" checked disabled> Task 2</li>
        </ul>
      EXPECTED

      assert_equal expected.gsub(%r{[\r\n\t]}, ''), to_html(text).gsub(%r{[\r\n\t]}, '').rstrip
    end

    def test_should_render_alert_blocks
      text = <<~MD
        > [!note]
        > This is a note.

        > [!tip]
        > This is a tip.

        > [!warning]
        > This is a warning.

        > [!caution]
        > This is a caution.

        > [!important]
        > This is a important.
      MD

      html = to_html(text)
      %w[note tip warning caution important].each do |alert|
        icon = Redmine::WikiFormatting::CommonMark::ALERT_TYPE_TO_ICON_NAME[alert]
        # rubocop:disable Layout/LineLength
        expected = %r{<div class="markdown-alert markdown-alert-#{alert}">\n<p class="markdown-alert-title"><svg class="s18 icon-svg" aria-hidden="true"><use href="/assets/icons-\w+.svg\#icon--#{icon}"></use></svg><span class="icon-label">#{alert.capitalize}</span></p>\n<p>This is a #{alert}.</p>\n</div>}
        # rubocop:enable Layout/LineLength
        assert_match expected, html
      end
    end

    def test_should_not_render_unknown_alert_type
      text = <<~MD
        > [!unknown]
        > This should not become an alert.
      MD

      html = to_html(text)

      assert_include "<blockquote>", html
      assert_include "[!unknown]", html
      assert_include "This should not become an alert.", html

      assert_not_include 'markdown-alert', html
    end

    private

    def assert_section_with_hash(expected, text, index)
      result = @formatter.new(text).get_section(index)

      assert_kind_of Array, result
      assert_equal 2, result.size
      assert_equal expected, result.first, "section content did not match"
      assert_equal ActiveSupport::Digest.hexdigest(expected), result.last, "section hash did not match"
    end
  end
end
