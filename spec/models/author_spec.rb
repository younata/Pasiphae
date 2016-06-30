require 'rails_helper'

RSpec.describe Author, type: :model do
  let!(:author) do
    a = Author.new(name: 'foo bar', email: 'example@example.com')
    a.save
    a
  end

  it 'is currently valid' do
    expect(author.valid?).to be_truthy
  end

  describe 'names' do
    it 'requires a name' do
      author.name = nil
      expect(author.valid?).to be_falsy
    end

    it 'does not allow duplicate names' do
      other_author = author.dup
      expect(other_author.valid?).to be_falsy

      other_author.name = author.name.upcase
      expect(other_author.valid?).to be_falsy

      other_author.name = 'some other string'
      expect(other_author.valid?).to be_truthy
    end
  end

  it 'does not require an email' do
    author.email = nil
    expect(author.valid?).to be_truthy
  end
end
