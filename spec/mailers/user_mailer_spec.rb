require "spec_helper"

describe UserMailer do
  describe "signup" do
    let(:user) { Fabricate(:user) }
    let(:mail) { UserMailer.signup(user) }

    it "renders the mail" do
      expect(mail.subject).to_not be_nil
      expect(mail.to).to eq([user.email])
      expect(mail.body.encoded).to match("bestätige")
    end
  end

  describe "validate" do
    let(:user) { Fabricate(:user) }
    let(:mail) { UserMailer.validate(user) }

    it "renders the mail" do
      expect(mail.subject).to_not be_nil
      expect(mail.to).to eq([user.email])
      expect(mail.body.encoded).to match("bestätige")
    end
  end

  describe "email_auth" do
    let(:email) { 'mursksi@furksi.de' }
    let(:mail) { UserMailer.email_auth(email, '123ABC') }

    it "renders the mail" do
      expect(mail.subject).to_not be_nil
      expect(mail.to).to eq([email])
      expect(mail.body.encoded).to match("nur 5 Minuten")
    end
  end

  describe "reminder" do
    let(:notice) { Fabricate(:notice) }
    let(:user) { notice.user }
    let(:mail) { UserMailer.reminder(user, [notice]) }

    it "renders the mail" do
      expect(mail.subject).to_not be_nil
      expect(mail.to).to eq([user.email])
      expect(mail.body.encoded).to match("rechtzeitig")
    end
  end
end
