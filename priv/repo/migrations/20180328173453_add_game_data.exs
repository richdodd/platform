defmodule Platform.Repo.Migrations.AddGameData do
  use Ecto.Migration

  def change do
    execute """
      insert into games
      (title, description, thumbnail, featured, inserted_at, updated_at)
      values
      ('Platformer','Platform game example.',
      'http://via.placeholder.com/300x200',true,
      current_date, current_date)
    """
  end
end
