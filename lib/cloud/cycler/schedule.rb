require 'cloud/cycler/namespace'
require 'cloud/cycler/errors'
require 'time'

Cloud::Cycler::InvalidSchedule = Class.new(Cloud::Cycler::Error)

# Represents a schedule when a resource should be on or off.
#
# Syntax example:
# "MTWTF-- 0800-1800" will be on between 08:00 and 18:00 Monday to Friday.
class Cloud::Cycler::Schedule
  def self.parse(str)
    str.match(/^([-M])([-T])([-W])([-T])([-F])([-S])([-S]) (\d{2})(\d{2})-(\d{2})(\d{2})$/) do |md|
      monday    = md[1] == 'M'
      tuesday   = md[2] == 'T'
      wednesday = md[3] == 'W'
      thursday  = md[4] == 'T'
      friday    = md[5] == 'F'
      saturday  = md[6] == 'S'
      sunday    = md[7] == 'S'

      start_hr  = md[8].to_i
      start_min = md[9].to_i
      stop_hr   = md[10].to_i
      stop_min  = md[11].to_i

      raise Cloud::Cycler::InvalidSchedule.new('Invalid start hour')   unless (0..23).include? start_hr
      raise Cloud::Cycler::InvalidSchedule.new('Invalid start minute') unless (0..59).include? start_min

      raise Cloud::Cycler::InvalidSchedule.new('Invalid stop hour')   unless (0..23).include? stop_hr
      raise Cloud::Cycler::InvalidSchedule.new('Invalid stop minute') unless (0..59).include? stop_min

      today = Date.today

      schedule = new(monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_hr, start_min, stop_hr, stop_min)
      return schedule
    end
    raise Cloud::Cycler::InvalidSchedule.new(str)
  end

  # * monday:    boolean
  # * tuesday:   boolean
  # * wednesday: boolean
  # * thursday:  boolean
  # * friday:    boolean
  # * start_hr:  integer (0-23)
  # * start_min: integer (0-59)
  # * stop_hr:   integer (0-23)
  # * stop_min:  integer (0-59)
  def initialize(monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_hr, start_min, stop_hr, stop_min)
    @days = [monday, tuesday, wednesday, thursday, friday, saturday, sunday]

    @start_hr  = start_hr
    @start_min = start_min
    @stop_hr   = stop_hr
    @stop_min  = stop_min
  end

  # Returns the string representation of the schedule.
  def to_s
    sched = ""
    sched << (@days[0] ? 'M' : '-')
    sched << (@days[1] ? 'T' : '-')
    sched << (@days[2] ? 'W' : '-')
    sched << (@days[3] ? 'T' : '-')
    sched << (@days[4] ? 'F' : '-')
    sched << (@days[5] ? 'S' : '-')
    sched << (@days[6] ? 'S' : '-')
    sprintf("#{sched} %02d%02d-%02d%02d", @start_hr, @start_min, @stop_hr, @stop_min)
  end

  # Returns the start and stop times for *today's* operational window
  def window
    now = Time.now
    today = now.to_date

    return false if !@days[today.cwday-1]

    start = Time.new(now.year, now.month, now.day, @start_hr, @start_min)
    stop  = Time.new(now.year, now.month, now.day, @stop_hr, @stop_min)
    # If the stop time is before the start time, it's probably because the stop
    # time is set to say 02:00. In this case, move the stop time forward to
    # tomorrow.
    if stop < start
      stop += 86400
    end

    [ start, now, stop ]
  end

  # Returns true if the current time is within the hours defined by the schedule
  def active?
    start, now, stop = window

    now.between?(start, stop)
  end

  # Returns true if the current time is within an hour of the start or stop
  # time in the schedule
  def interesting?
    start, now, stop = window

    now.between?(start,start+3600) || now.between?(stop,stop+3600)
  end
end
