# This file is part of the OpenWISP Manager
#
# Copyright (C) 2012 OpenWISP.org
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

class Ethernet < ActiveRecord::Base
  acts_as_authorization_object :subject_class_name => 'Operator'

  validates_presence_of :name,
                        :unless => Proc.new { |b| b.machine.is_a?(AccessPoint) and b.name.nil? }
  validates_uniqueness_of :name, :scope => [:machine_id, :machine_type],
                          :unless => Proc.new { |b| b.machine.is_a?(AccessPoint) and b.name.nil? }
  validates_format_of :name, :with => /\A[a-z][\w\d_\.]*\Z/i,
                      :unless => Proc.new { |b| b.machine.is_a?(AccessPoint) and b.name.nil? }
  validates_length_of :name, :maximum => 8,
                      :unless => Proc.new { |b| b.machine.is_a?(AccessPoint) and b.name.nil? }
  validates_numericality_of :output_band, :greater_than => 0, :allow_blank => true
  validates_numericality_of :input_band, :greater_than => 0, :allow_blank => true

  belongs_to :bridge
  belongs_to :machine, :polymorphic => true

  has_many :vlans, :as => :interface, :dependent => :destroy
  has_many :subinterfaces, :as => :interface, :class_name => 'Vlan',
           :foreign_key => 'interface_id', :conditions => {:interface_type => 'Ethernet'}
  has_one :l2tc, :as => :shapeable, :dependent => :destroy

  # Instance template
  belongs_to :ethernet_template
  belongs_to :template, :class_name => 'EthernetTemplate', :foreign_key => :ethernet_template_id

  somehow_has :one => :machine, :as => :related_access_point, :if => Proc.new { |instance| instance.is_a? AccessPoint }

  after_save :outdate_configuration_if_required
  after_destroy :outdate_configuration_if_required

  def link_to_template(t)
    self.template = t

    # Create (and link to appropriate templates) subinterfaces (i.e.: vlans)
    t.vlan_templates.each do |vt|
      nv = self.vlans.build(:interface => self)
      nv.link_to_template(vt)
      unless nv.save!
        raise ActiveRecord::Rollback
      end
    end

    # Create a new l2tc profile for this interface
    nl = self.l2tc = L2tc.new(:access_point => self.machine, :shapeable => self)
    nl.link_to_template(template.l2tc_template)
    unless nl.save!
      raise ActiveRecord::Rollback
    end
  end

  def do_bridge!(b)
    self.bridge = b
    self.save!
  end

  def do_unbridge!
    self.bridge = nil
    self.save!
  end

  # Accessor methods (read)
  def name
    if read_attribute(:name).blank? and !template.nil?
      return template.name
    end

    read_attribute(:name)
  end

  def friendly_name
    self.name
  end

  def output_band
    if read_attribute(:output_band).blank? and !template.nil?
      return template.output_band
    end

    read_attribute(:output_band)
  end

  private

  OUTDATING_ATTRIBUTES = [:name, :bridge_id, :output_band, :input_band]

  def outdate_configuration_if_required
    if destroyed? or OUTDATING_ATTRIBUTES.any? { |attribute| send "#{attribute}_changed?" }
      related_access_point.outdate_configuration! if related_access_point
    end
  end

end
