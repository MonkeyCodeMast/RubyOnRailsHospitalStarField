class AddAssingedAtPathwayWeek < ActiveRecord::Migration[6.0]
  def change
    add_column :assigned_pathway_week_actions, :assigned_at, :datetime
  end
end
