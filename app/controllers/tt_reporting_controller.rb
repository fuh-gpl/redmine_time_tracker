class TtReportingController < ApplicationController
  unloadable

  menu_item :time_tracker_menu_tab_reporting
  before_filter :authorize_global

  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  helper :time_trackers
  include TimeTrackersHelper

  def index
    fetch_query

    if @query_bookings.valid?
      @limit = per_page_option

      @booking_count = @query_bookings.booking_count
      @booking_pages = Paginator.new self, @booking_count, @limit, params['page']
      @offset ||= @booking_pages.current.offset
      @bookings = @query_bookings.bookings(:order => sort_bookings_clause,
                                  :offset => @offset,
                                  :limit => @limit)
      @booking_count_by_group = @query_bookings.booking_count_by_group

    end

    fetch_chart_data

    render :template => 'tt_reporting/index', :locals => {:query => @query_bookings}
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def print_report
    fetch_query

    if @query_bookings.valid?
      @booking_count = @query_bookings.booking_count
      @bookings = @query_bookings.bookings(:order => sort_bookings_clause)
      @booking_count_by_group = @query_bookings.booking_count_by_group
    end

    @total_booked_time = help.time_dist2string((total_booked*3600).to_i)
    fetch_chart_data

    # prepare logo settings
    @logo_url = Setting.plugin_redmine_time_tracker[:report_logo_url]
    Setting.plugin_redmine_time_tracker[:report_logo_url].starts_with?("http://") ? @logo_external = true : @logo_external = false
    Setting.plugin_redmine_time_tracker[:report_logo_width].blank? ? @logo_width = "150" : @logo_width = Setting.plugin_redmine_time_tracker[:report_logo_width]

    render "print_report", :layout => false, :locals => {:query => @query_bookings}
  end
end

def total_booked
  hours = 0
  @bookings.each do |tb|
    hours += tb.hours_spent
  end
  hours
end

private

def fetch_query
  time_bookings_query

  sort_init(@query_bookings.sort_criteria.empty? ? [['tt_booking_date', 'desc']] : @query_bookings.sort_criteria)
  tt_sort_update(:sort_bookings, @query_bookings.sortable_columns, "tt_booking_sort")

  #tt_retrieve_query
  ## overwrite the initial column_names cause if no columns are specified, the Query class uses default values
  ## which depend on issues
  #@query_bookings.column_names = @query_bookings.column_names || [:project, :tt_booking_date, :get_formatted_start_time, :get_formatted_stop_time, :issue, :comments, :get_formatted_time]
  #
  ## temporarily limit the available filters and columns for the view!
  #@query_bookings.available_filters.delete_if { |key, value| !key.to_s.start_with?('tt_') }
  #@query_bookings.available_columns.delete_if { |item| !([:id, :user, :project, :tt_booking_date, :get_formatted_start_time, :get_formatted_stop_time, :issue, :comments, :get_formatted_time].include? item.name) }
  #
  #sort_init(@query_bookings.sort_criteria.empty? ? [['tt_booking_date', 'desc']] : @query_bookings.sort_criteria)
  #sort_update(@query_bookings.sortable_columns)
end

def fetch_chart_data
  if @query_bookings.valid? && !(@bookings.empty? || @bookings.nil?)
    # if the user changes the date-order for the table values, we have to reorder it for the chart
    start_date = [@bookings.last.started_on.to_date, @bookings.first.started_on.to_date].min
    stop_date = [@bookings.last.started_on.to_date, @bookings.first.started_on.to_date].max
    @chart_data = Array.new
    @chart_ticks = Array.new
    @highlighter_data = Array.new

    (start_date..stop_date).map do |date|
      hours = 0
      @bookings.each do |tb|
        hours += tb.hours_spent if tb.started_on.to_date == date
      end
      @chart_data.push(hours)
      @highlighter_data.push([date, hours])

      #to get readable labels, we have to blank out some of them if there are to many
      if (stop_date - start_date).days > 6.days
        # only set six labels and set the other blank
        if (date - start_date).days % 6.days == 0
          @chart_ticks.push(date)
        else
          @chart_ticks.push("")
        end
      else
        # print date for every data-entry
        @chart_ticks.push(date)
      end
    end
  end
end