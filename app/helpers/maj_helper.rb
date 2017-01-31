module MajHelper
  def maj_counter
    ApplicationRecord.transaction do
      Timeline.find_each do |timeline|
        timeline.update_columns(nb_comments: Comment.where(timeline_id: timeline.id).count,
                                nb_references: Reference.where(timeline_id: timeline.id).where.not(title_fr: '').count)
      end
    end
  end

  def maj_refill
    ApplicationRecord.transaction do
      Reference.find_each.map{|r| r.comments.map(&:save)}
      Timeline.find_each.map{|t| t.summaries.map(&:save)}
      Timeline.find_each.map{|t| t.frames.map(&:save)}
    end
  end

  def maj_update_binary
    ApplicationRecord.transaction do
      Timeline.find_each.map{|t| t.references.each{ |r| r.update_columns(binary: t.binary)}}
    end
  end

  def maj_content
    ApplicationRecord.transaction do
      Summary.find_each.map{|t| t.save! }
      Comment.find_each.map{|t| t.save! }
      Frame.find_each.map{|t| t.save! }
    end
  end
end
