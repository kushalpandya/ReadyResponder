class Event < ActiveRecord::Base
  before_save :calc_duration

  attr_accessible :title, :description, :category, :course_id, :duration, :start_time, :end_time, :instructor, :location, :status, :timecard_ids, :person_ids, :comments

  def end_date_cannot_be_before_start
    if ((!end_time.blank?) and (!start_time.blank?)) and end_time < start_time
      errors.add(:end_time, "must be after the start, unless you are the Doctor")
    end
  end
  def end_date_cannot_be_before_start
    if ((!end_time.blank?) and (!start_time.blank?)) and end_time < start_time
      errors.add(:end_time, "must be after the start, unless you are the Doctor")
    end
  end

  validates_presence_of :category, :title, :status
  validate :end_date_cannot_be_before_start
  validates_presence_of :start_time
  validates_presence_of :end_time, :if => :completed?

  has_many :certs
  belongs_to :course
  has_many :activities, as: :loggable

  has_many :timecards
  has_many :people, :through => :timecards
  has_many :notifications

  accepts_nested_attributes_for :timecards
  accepts_nested_attributes_for :certs

  STATUS_CHOICES = ['Scheduled', 'In-session', 'Completed', 'Cancelled', "Closed"]
  CATEGORY_CHOICES = ['Training', 'Patrol', 'Meeting', 'Admin', 'Event']

  def to_s
    title
  end
  def roster(group)  # This returns people
    self.timecards.send(group.downcase).map { |tc| tc.person }
  end
  def timecards_which_are(group)
    self.timecards.send(group.downcase)
  end
  def manhours
    self.timecards.sum('actual_duration')
  end
  def create_timecards_for_unknown_people
    Person.order('title_order').active - self.people
  end

  def completed?
    status == "Completed"
  end

  def schedule(schedulable, schedule_action, timecard = Timecard.new )
    @card = timecard
    @card.person = schedulable if schedulable.class.name == "Person"
    @card.event = self
    case schedule_action
      when "Available", "Scheduled", "Unavailable"
        @card.intention = schedule_action
        @card.intended_start_time = self.start_time
        @card.intended_end_time = self.end_time
      when "Worked"
        @card.outcome = schedule_action
        @card.actual_start_time = self.start_time
        @card.actual_end_time = self.end_time
    end
    @card.save
    return @card
  end 

  def ready_to_schedule?(schedule_action)
    return false if self.nil? 
    return false if schedule_action.blank?
    return false if self.status.blank?
    return false if self.status == "Closed"

    case schedule_action
      when "Available", "Scheduled", "Unavailable"
        return false if self.start_time.blank? 
      when "Worked"
        return false if self.start_time.blank? or self.end_time.blank?
    end
    return true
  end

private
  def calc_duration #This is also used in timecards; it should be extracted out
    if !(start_time.blank?) and !(end_time.blank?)
      self.duration = ((end_time - start_time) / 1.hour).round(2) || 0
    end
  end

end
