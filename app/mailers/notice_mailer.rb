class NoticeMailer < ActionMailer::Base
  default from: "peter@weg-li.de", bcc: "peter@weg-li.de"

  def charge(notice)
    @notice = notice
    @user = notice.user

    notice.photos.each do |photo|
      variant = photo.variant(PhotoHelper::CONFIG[:default]).processed
      attachments[photo.filename.to_s] = photo.service.download(variant.key)
    end

    subject = "Anzeige #{@notice.registration} #{@notice.charge}"
    mail subject: subject, to: notice.district.email, cc: "#{@user.name} <#{@user.email}>", reply_to: "#{@user.name} <#{@user.email}>", from: "#{@user.name} <#{@user.wegli_email}>"
  end
end
