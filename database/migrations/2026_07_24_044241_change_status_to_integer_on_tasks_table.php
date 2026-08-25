<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
  public function up(): void
  {
    DB::statement("
      ALTER TABLE tasks
      ALTER COLUMN status TYPE smallint
      USING (
        CASE status
          WHEN 'todo' THEN 0
          WHEN 'in_progress' THEN 1
          WHEN 'done' THEN 2
          ELSE 0
        END
      )
    ");
  }

  public function down(): void
  {
    DB::statement("
      ALTER TABLE tasks
      ALTER COLUMN status TYPE varchar(255)
      USING (
        CASE status
          WHEN 0 THEN 'todo'
          WHEN 1 THEN 'in_progress'
          WHEN 2 THEN 'done'
          ELSE 'todo'
        END
      )
    ");
  }
};
