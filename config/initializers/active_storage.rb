Rails.application.config.active_storage.analyzers.prepend(EXIFAnalyzer)

ActiveStorage.service_urls_expire_in = 1.week


require 'active_storage/downloader'
require 'active_storage/direct_uploads_controller'

ActiveStorage::DirectUploadsController.instance_eval do
  rescue_from(ActionController::InvalidAuthenticityToken, with: lambda { redirect_to('/', alert: 'Ihre Sitzung ist abgelaufen') })
end

ActiveStorage::RepresentationsController.instance_eval do
  rescue_from(MiniMagick::Error, with: lambda { head(404) })
end

module ActiveStorage
  class Downloader
    def open(key, checksum:, name: "ActiveStorage-", tmpdir: nil)
      tmpdir ||= Rails.root.join('tmp')
      path = "#{tmpdir}/#{key}#{Array(name).last}"
      if File.exists?(path)
        File.open(path, 'rb') do |file|
          yield file
        end
      else
        File.open(path, 'w+') do |file|
          download key, file
          verify_integrity_of file, checksum: checksum
          yield file
        end
      end
    end
  end
end
