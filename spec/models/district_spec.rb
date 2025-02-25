require 'spec_helper'

describe District do
  let(:district) { Fabricate.build(:district) }

  context "validation" do
    it "is valid" do
      expect(district).to be_valid
    end
  end

  context "acts_as_api" do
    it "generates proper results" do
      expect(district.as_api_response(:public_beta).keys).to eql(%i(name zip email prefix latitude longitude created_at updated_at))
    end
  end
end
