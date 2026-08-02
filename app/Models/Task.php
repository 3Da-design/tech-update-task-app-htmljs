<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * @property int $id
 * @property int $user_id
 * @property string $title
 * @property string|null $description
 * @property string $status
 * @property string $priority
 * @property Carbon|null $due_date
 */
#[Fillable(['user_id', 'title', 'description', 'status', 'priority', 'due_date'])]
class Task extends Model
{
  protected function casts(): array
  {
    return [
      'due_date' => 'date',
    ];
  }

  public function user(): BelongsTo
  {
    return $this->belongsTo(User::class);
  }
}
