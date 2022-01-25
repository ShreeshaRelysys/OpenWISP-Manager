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

class CustomScriptsController < ApplicationController
  layout nil

  before_filter :load_wisp
  before_filter :load_access_point
    
  access_control do
    default :deny

    actions :index, :show do
      allow :wisps_viewer
      allow :access_points_viewer, :of => :wisp
    end

    actions :new, :create do
      allow :wisps_creator
      allow :access_points_custom_scripts_creator, :of => :wisp
    end

    actions :edit, :update do
      allow :wisps_manager
      allow :access_points_custom_scripts_manager, :of => :wisp
    end

    actions :destroy do
      allow :wisps_destroyer
      allow :access_points_custom_scripts_destroyer, :of => :wisp
    end
  end
  
  # GET /wisps/:wisp_id/access_points/:access_point_id/custom_script
  def index
    @custom_scripts = @access_point.custom_scripts.find(:all)
    @custom_script_templates = @access_point.access_point_template.custom_script_templates.find(:all)

    respond_to do |format|
      format.html # index.html.erb
    end
  end
  
  # GET /wisps/:wisp_id/access_points/:access_point_id/custom_script_template/1
  def show
    @custom_script = @access_point.custom_script.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def new
    @custom_script = CustomScript.new()

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def create
    @custom_script = @access_point.custom_scripts.new(params[:custom_script])

     respond_to do |format|
       if @custom_script.save
         format.html { redirect_to(wisp_access_point_custom_scripts_url(@wisp, @access_point)) }
       else
         format.html { render :action => "new" }
       end
     end
  end
  
  # GET /custom_script/1/edit
  def edit
    @custom_script = @access_point.custom_scripts.find(params[:id])
  end

  def update
    @custom_script = @access_point.custom_scripts.find(params[:id])
    respond_to do |format|
      if @custom_script.update_attributes(params[:custom_script])
        format.html { redirect_to(wisp_access_point_custom_scripts_url(@wisp, @access_point)) }
      else
        format.html { render :action => "edit" }
        end
    end
  end

  def destroy
    @custom_script = CustomScript.find(params[:id])
    @custom_script.destroy
    
    respond_to do |format|
      format.html { redirect_to(wisp_access_point_custom_scripts_url(@wisp, @access_point)) }
    end
  end
end
