require 'rails_helper'

RSpec.describe Avatar::AvatarFromUrlJob do
  let(:valid_url) { 'https://example.com/avatar.png' }
  let(:tempfile) do
    t = Tempfile.new(['avatar', '.png'], binmode: true)
    t.write(Rails.root.join('spec/assets/avatar.png').binread)
    t.rewind
    t
  end
  let(:safe_fetch_result) do
    SafeFetch::Result.new(tempfile: tempfile, filename: 'avatar.png', content_type: 'image/png')
  end

  after do
    tempfile.close! unless tempfile.closed?
  end

  it 'enqueues the job' do
    contact = create(:contact)
    expect { described_class.perform_later(contact, 'https://example.com/avatar.png') }
      .to have_enqueued_job(described_class).on_queue('purgable')
  end

  context 'with rate-limited avatarable (Contact)' do
    let(:avatarable) { create(:contact) }

    it 'attaches and updates sync attributes' do
      expect(SafeFetch).to receive(:fetch)
        .with(valid_url, max_bytes: Avatar::AvatarFromUrlJob::MAX_DOWNLOAD_SIZE, allowed_content_type_prefixes: ['image/'])
        .and_yield(safe_fetch_result)
      described_class.perform_now(avatarable, valid_url)
      avatarable.reload
      expect(avatarable.avatar).to be_attached
      expect(avatarable.additional_attributes['avatar_url_hash']).to eq(Digest::SHA256.hexdigest(valid_url))
      expect(avatarable.additional_attributes['last_avatar_sync_at']).to be_present
    end

    it 'returns early when rate limited' do
      ts = 30.seconds.ago.iso8601
      avatarable.update(additional_attributes: { 'last_avatar_sync_at' => ts })
      expect(SafeFetch).not_to receive(:fetch)
      described_class.perform_now(avatarable, valid_url)
      avatarable.reload
      expect(avatarable.avatar).not_to be_attached
      expect(avatarable.additional_attributes['last_avatar_sync_at']).to be_present
      expect(Time.zone.parse(avatarable.additional_attributes['last_avatar_sync_at']))
        .to be > Time.zone.parse(ts)
      expect(avatarable.additional_attributes['avatar_url_hash']).to eq(Digest::SHA256.hexdigest(valid_url))
    end

    it 'returns early when hash unchanged' do
      avatarable.update(additional_attributes: { 'avatar_url_hash' => Digest::SHA256.hexdigest(valid_url) })
      expect(SafeFetch).not_to receive(:fetch)
      described_class.perform_now(avatarable, valid_url)
      expect(avatarable.avatar).not_to be_attached
      avatarable.reload
      expect(avatarable.additional_attributes['last_avatar_sync_at']).to be_present
      expect(avatarable.additional_attributes['avatar_url_hash']).to eq(Digest::SHA256.hexdigest(valid_url))
    end

    it 'updates sync attributes even when URL is invalid' do
      invalid_url = 'invalid_url'
      expect(SafeFetch).not_to receive(:fetch)
      described_class.perform_now(avatarable, invalid_url)
      avatarable.reload
      expect(avatarable.avatar).not_to be_attached
      expect(avatarable.additional_attributes['last_avatar_sync_at']).to be_present
      expect(avatarable.additional_attributes['avatar_url_hash']).to eq(Digest::SHA256.hexdigest(invalid_url))
    end

    it 'updates sync attributes when content type is unsupported' do
      expect(SafeFetch).to receive(:fetch).and_raise(SafeFetch::UnsupportedContentTypeError, 'content-type not allowed: application/xml')

      described_class.perform_now(avatarable, valid_url)
      avatarable.reload

      expect(avatarable.avatar).not_to be_attached
      expect(avatarable.additional_attributes['last_avatar_sync_at']).to be_present
      expect(avatarable.additional_attributes['avatar_url_hash']).to eq(Digest::SHA256.hexdigest(valid_url))
    end

    it 'updates sync attributes when the URL is blocked as unsafe (SSRF)' do
      expect(SafeFetch).to receive(:fetch).and_raise(SafeFetch::UnsafeUrlError, 'prohibited IP address')

      described_class.perform_now(avatarable, valid_url)
      avatarable.reload

      expect(avatarable.avatar).not_to be_attached
      expect(avatarable.additional_attributes['last_avatar_sync_at']).to be_present
      expect(avatarable.additional_attributes['avatar_url_hash']).to eq(Digest::SHA256.hexdigest(valid_url))
    end
  end

  context 'with regular avatarable' do
    let(:avatarable) { create(:agent_bot) }

    it 'downloads and attaches avatar' do
      expect(SafeFetch).to receive(:fetch)
        .with(valid_url, max_bytes: Avatar::AvatarFromUrlJob::MAX_DOWNLOAD_SIZE, allowed_content_type_prefixes: ['image/'])
        .and_yield(safe_fetch_result)
      described_class.perform_now(avatarable, valid_url)
      expect(avatarable.avatar).to be_attached
    end
  end

  it 'does not raise error when fetch returns a 404' do
    contact = create(:contact)
    expect(SafeFetch).to receive(:fetch).and_raise(SafeFetch::HttpError, '404 Not Found')

    expect { described_class.perform_now(contact, valid_url) }.not_to raise_error
  end

  it 'skips sync attribute updates when URL is nil' do
    contact = create(:contact)
    expect(SafeFetch).not_to receive(:fetch)

    expect { described_class.perform_now(contact, nil) }.not_to raise_error

    contact.reload
    expect(contact.additional_attributes['last_avatar_sync_at']).to be_nil
    expect(contact.additional_attributes['avatar_url_hash']).to be_nil
  end
end
