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

class L2tcTemplate < ActiveRecord::Base
  acts_as_authorization_object :subject_class_name => 'Operator'

  belongs_to :shapeable_template, :polymorphic => true
  belongs_to :access_point_template

  # Template instances
  has_many :l2tcs, :dependent => :destroy

  somehow_has :many => :access_points, :through => :access_point_template

  # No outdating configuration logic here
  # l2tc has no attribute that could be outdate access points configuration...
  # (see ethernet, radio, tap, vlan and vap)

  def validate
    input_sum = 0
    output_sum = 0
    self.shapeable_template.subinterfaces.each do |s|
      input_sum += s.input_band_percent unless s.input_band_percent.blank? or s.input_band_percent.nil?
      output_sum += s.output_band_percent unless s.output_band_percent.blank? or s.output_band_percent.nil?
    end

    if input_sum > 100 or output_sum > 100
      errors.add_to_base(:Subinterface_percentage_sum_greater_than_100_perc)
      return false
    end

    if input_sum > 0 and self.shapeable_template.input_band.blank?
      errors.add_to_base(:Input_interface_must_be_specified)
      return false
    end

    if output_sum > 0 and self.shapeable_template.output_band.blank?
      errors.add_to_base(:Output_interface_must_be_specified)
      return false
    end

    true
  end

end
