# encoding: utf-8
class Store < ActiveRecord::Base
  include UUIDHelper
  acts_as_org

  has_many :buys

  validates_presence_of :name, :address
end