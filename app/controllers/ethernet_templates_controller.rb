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

class EthernetTemplatesController < ApplicationController
  layout nil

  before_filter :load_wisp
  before_filter :load_access_point_template
  before_filter :load_ethernet_template, :except => [ :index, :new, :create ]
    
  access_control do
    default :deny

    actions :index, :show do
      allow :wisps_viewer
      allow :access_point_templates_viewer, :of => :wisp
    end

    actions :new, :create do
      allow :wisps_creator
      allow :access_point_templates_creator, :of => :wisp
    end

    actions :edit, :update do
      allow :wisps_manager
      allow :access_point_templates_manager, :of => :wisp
    end

    actions :destroy do
      allow :wisps_destroyer
      allow :access_point_templates_destroyer, :of => :wisp
    end
  end

  def index
    @ethernet_templates = @access_point_template.ethernet_templates.all

    respond_to do |format|
      format.html # index.html.erb
    end
  end

  def show

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def new
    @ethernet_template = EthernetTemplate.new()

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def edit
    
  end

  def create
    @ethernet_template = @access_point_template.ethernet_templates.new(params[:ethernet_template])
    
    respond_to do |format|
      if @ethernet_template.save
        #flash[:notice] = 'Ethernet NIC was successfully created.'
        format.html { redirect_to(wisp_access_point_template_ethernet_templates_url(@wisp, @access_point_template)) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update

    respond_to do |format|
      if @ethernet_template.update_attributes(params[:ethernet_template])
        format.html { redirect_to(wisp_access_point_template_ethernet_templates_url(@wisp, @access_point_template)) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    @ethernet_template.destroy

    respond_to do |format|
      format.html { redirect_to(wisp_access_point_template_ethernet_templates_url(@wisp, @access_point_template)) }
    end
  end

  private

  def load_ethernet_template
    @ethernet_template = @access_point_template.ethernet_templates.find(params[:id])
  end
end
