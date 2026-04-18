require 'rails_helper'

RSpec.describe Messages::MarkdownRendererService, type: :service do
  describe '#render' do
    context 'when content is blank' do
      it 'returns the content as-is for nil' do
        result = described_class.new(nil, 'Channel::Whatsapp').render
        expect(result).to be_nil
      end

      it 'returns the content as-is for empty string' do
        result = described_class.new('', 'Channel::Whatsapp').render
        expect(result).to eq('')
      end
    end

    context 'when channel is Channel::Whatsapp' do
      let(:channel_type) { 'Channel::Whatsapp' }

      it 'converts bold from double to single asterisk' do
        content = '**bold text**'
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('*bold text*')
      end

      it 'keeps italic with underscore' do
        content = '_italic text_'
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('_italic text_')
      end

      it 'keeps code with backticks' do
        content = '`code`'
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('`code`')
      end

      it 'converts links to URLs only' do
        content = '[link text](https://example.com)'
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('https://example.com')
      end

      it 'handles combined formatting' do
        content = '**bold** _italic_ `code` [link](https://example.com)'
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('*bold* _italic_ `code` https://example.com')
      end

      it 'handles nested formatting' do
        content = '**bold _italic_**'
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('*bold _italic_*')
      end

      it 'preserves unordered list with dash markers' do
        content = "- item 1\n- item 2\n- item 3"
        result = described_class.new(content, channel_type).render
        expect(result).to include('- item 1')
        expect(result).to include('- item 2')
        expect(result).to include('- item 3')
      end

      it 'converts asterisk unordered lists to dash markers' do
        content = "* item 1\n* item 2\n* item 3"
        result = described_class.new(content, channel_type).render
        expect(result).to include('- item 1')
        expect(result).to include('- item 2')
        expect(result).to include('- item 3')
      end

      it 'preserves ordered list markers with numbering' do
        content = "1. first step\n2. second step\n3. third step"
        result = described_class.new(content, channel_type).render
        expect(result).to include('1. first step')
        expect(result).to include('2. second step')
        expect(result).to include('3. third step')
      end

      it 'preserves newlines in plain text without list markers' do
        content = "Line 1\nLine 2\nLine 3"
        result = described_class.new(content, channel_type).render
        expect(result).to include("Line 1\nLine 2\nLine 3")
        expect(result).not_to include('Line 1 Line 2')
      end

      it 'preserves multiple consecutive newlines for spacing' do
        content = "Para 1\n\n\n\nPara 2"
        result = described_class.new(content, channel_type).render
        expect(result.scan("\n").count).to eq(4)
        expect(result).to include("Para 1\n\n\n\nPara 2")
      end

      it 'renders code blocks as plain text' do
        content = "```\ncode here\n```"
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('code here')
      end

      it 'renders indented code blocks as plain text preserving exact content' do
        content = '    indented code line'
        result = described_class.new(content, channel_type).render
        expect(result).to eq('indented code line')
      end

      it 'handles code blocks with emojis and special characters without stack overflow' do
        content = "    first line\n    🌐 second line\n"
        result = described_class.new(content, channel_type).render
        expect(result).to eq("first line\n🌐 second line")
      end
    end

    context 'when channel is Channel::Instagram' do
      let(:channel_type) { 'Channel::Instagram' }

      it 'converts bold from double to single asterisk' do
        content = '**bold text**'
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('*bold text*')
      end

      it 'keeps italic with underscore' do
        content = '_italic text_'
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('_italic text_')
      end

      it 'strips code backticks' do
        content = '`code`'
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('code')
      end

      it 'converts links to URLs only' do
        content = '[link text](https://example.com)'
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('https://example.com')
      end

      it 'preserves bullet list markers' do
        content = "- first item\n- second item"
        result = described_class.new(content, channel_type).render
        expect(result).to include('- first item')
        expect(result).to include('- second item')
      end

      it 'preserves ordered list markers with numbering' do
        content = "1. first step\n2. second step"
        result = described_class.new(content, channel_type).render
        expect(result).to include('1. first step')
        expect(result).to include('2. second step')
      end

      it 'preserves newlines in plain text without list markers' do
        content = "Line 1\nLine 2\nLine 3"
        result = described_class.new(content, channel_type).render
        expect(result).to include("Line 1\nLine 2\nLine 3")
        expect(result).not_to include('Line 1 Line 2')
      end

      it 'preserves multiple consecutive newlines for spacing' do
        content = "Para 1\n\n\n\nPara 2"
        result = described_class.new(content, channel_type).render
        expect(result.scan("\n").count).to eq(4)
        expect(result).to include("Para 1\n\n\n\nPara 2")
      end

      it 'renders code blocks as plain text' do
        content = "```\ncode here\n```"
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('code here')
      end

      it 'renders indented code blocks as plain text preserving exact content' do
        content = '    indented code line'
        result = described_class.new(content, channel_type).render
        expect(result).to eq('indented code line')
      end

      it 'handles code blocks with emojis and special characters without stack overflow' do
        content = "    first line\n    🌐 second line\n"
        result = described_class.new(content, channel_type).render
        expect(result).to eq("first line\n🌐 second line")
      end
    end



    context 'when channel is Channel::FacebookPage' do
      let(:channel_type) { 'Channel::FacebookPage' }

      it 'converts bold to single asterisk like Instagram' do
        content = '**bold text**'
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('*bold text*')
      end

      it 'strips unsupported formatting' do
        content = '`code` ~~strike~~'
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('code ~~strike~~')
      end

      it 'preserves bullet list markers like Instagram' do
        content = "- first item\n- second item"
        result = described_class.new(content, channel_type).render
        expect(result).to include('- first item')
        expect(result).to include('- second item')
      end

      it 'preserves ordered list markers with numbering like Instagram' do
        content = "1. first step\n2. second step"
        result = described_class.new(content, channel_type).render
        expect(result).to include('1. first step')
        expect(result).to include('2. second step')
      end

      it 'renders code blocks as plain text' do
        content = "```\ncode here\n```"
        result = described_class.new(content, channel_type).render
        expect(result.strip).to eq('code here')
      end

      it 'handles code blocks with emojis and special characters without stack overflow' do
        content = "    first line\n    🌐 second line\n"
        result = described_class.new(content, channel_type).render
        expect(result).to eq("first line\n🌐 second line")
      end
    end


    context 'when testing all formatting types' do
      let(:channel_type) { 'Channel::Whatsapp' }

      it 'handles ordered lists with proper numbering' do
        content = "1. first\n2. second\n3. third"
        result = described_class.new(content, channel_type).render
        expect(result).to include('1. first')
        expect(result).to include('2. second')
        expect(result).to include('3. third')
      end
    end

    context 'when channel is unknown' do
      let(:channel_type) { 'Channel::Unknown' }

      it 'returns content as-is' do
        content = '**bold** _italic_'
        result = described_class.new(content, channel_type).render
        expect(result).to eq(content)
      end
    end

    # Shared test for all text-based channels that preserve multiple newlines
    # This tests the real-world scenario where frontend sends newlines with whitespace between them
    context 'when content has multiple newlines with whitespace between them' do
      # This mimics what frontends often send: newlines with spaces/tabs between them
      let(:content_with_whitespace_newlines) { "hello   \n   \n   \n   \n   \n   \n   \n   \n   \n   \n   \n   \n   \n   \n   \n   \n \n\nhello wow" }

      %w[
        Channel::Whatsapp
        Channel::Instagram
        Channel::FacebookPage
      ].each do |channel_type|
        context "when channel is #{channel_type}" do
          it 'normalizes whitespace-only lines and preserves multiple newlines' do
            result = described_class.new(content_with_whitespace_newlines, channel_type).render
            # Should preserve most of the newlines (at least 10+)
            # The exact count may vary slightly by renderer, but should be significantly more than 1-2
            expect(result.scan("\n").count).to be >= 10
            # Should not collapse everything to just 1-2 newlines
            expect(result.scan("\n").count).to be > 5
          end
        end
      end
    end
  end
end
