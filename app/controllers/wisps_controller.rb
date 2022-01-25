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

class WispsController < ApplicationController
  include Addons::Mappable

  before_filter :load_wisp, :except => [:index, :new, :create]

  access_control do
    default :deny

    actions :index, :show, :ajax_stats do
      allow :wisps_viewer
      allow :wisp_viewer, :of => :wisp
    end

    actions :new, :create do
      allow :wisps_creator, :of => :wisp
    end

    actions :edit, :update do
      allow :wisps_manager
      allow :wisp_manager, :of => :wisp
    end

    actions :destroy do
      allow :wisps_destroyer
    end
  end

  # GET /wisps
  def index
    @wisps = Wisp.find(:all)

    respond_to do |format|
      format.html # index.html.erb
    end
  end

  # GET /wisps/1
  def show
    @access_points = @wisp.access_points.find(:all)

    @latlon = @access_points.length > 0 ? get_center_zoom(@wisp.access_points) : @wisp.geocode

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  # GET /wisps/new
  def new
    @wisp = Wisp.new
    @wisp.ca = Ca.new

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # GET /wisps/1/edit
  def edit
    respond_to do |format|
      format.html # edit.html.erb
    end
  end

  # POST /wisps
  def create
    @wisp = Wisp.new(params[:wisp])
    @wisp.ca.cn = @wisp.name

    respond_to do |format|
      if @wisp.save
        flash[:notice] = t(:Wisp_was_successfully_created)
        format.html { redirect_to(wisps_url) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  # POST /wisps/1
  def update
    respond_to do |format|
      if @wisp.update_attributes(params[:wisp])
        flash[:notice] = t(:Wisp_was_successfully_updated)
        format.html { redirect_to(wisp_url(@wisp)) }
      else
        format.html { render :action => "edit" }
      end
    end
  end


  # DELETE /wisps/1
  def destroy
    @wisp.destroy

    respond_to do |format|
      format.html { redirect_to(wisps_url) }
    end
  end

  # Ajax Methods
  def ajax_stats
    respond_to do |format|
      format.html { render :partial => "stats", :object => @wisp }
    end
  end

end
