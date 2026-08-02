<?php

namespace App\Repositories;

use App\Models\Task;
use App\Repositories\Contracts\TaskRepositoryInterface;
use Illuminate\Database\Eloquent\Collection;

class TaskRepository implements TaskRepositoryInterface
{
  public function getFiltered(int $userId, array $filters = []): Collection
  {
    $query = Task::query()->where('user_id', $userId);

    $title = $filters['title'] ?? null;
    if (is_string($title) && $title !== '') {
      $query->where('title', 'like', '%'.$this->escapeLike($title).'%');
    }

    $status = $filters['status'] ?? null;
    if (is_string($status) && $status !== '') {
      $query->where('status', $status);
    }

    $priority = $filters['priority'] ?? null;
    if (is_string($priority) && $priority !== '') {
      $query->where('priority', $priority);
    }

    $prioritySort = $filters['priority_sort'] ?? 'asc';
    $priorityDirection = $prioritySort === 'desc' ? 'desc' : 'asc';
    $query->orderByRaw(
      "CASE priority WHEN 'low' THEN 1 WHEN 'medium' THEN 2 WHEN 'high' THEN 3 ELSE 4 END {$priorityDirection}"
    );

    $dueSort = $filters['due_date_sort'] ?? 'asc';
    $direction = $dueSort === 'desc' ? 'desc' : 'asc';
    $query->orderByRaw('due_date IS NULL DESC')->orderBy('due_date', $direction)->orderBy('id');

    /** @var Collection<int, Task> */
    return $query->get();
  }

  public function findById(int $userId, int $taskId): ?Task
  {
    /** @var Task|null */
    return Task::query()
      ->where('user_id', $userId)
      ->whereKey($taskId)
      ->first();
  }

  public function create(int $userId, array $attributes): Task
  {
    $task = new Task;
    $task->fill($attributes);
    $task->user_id = $userId;
    $task->save();

    return $task->fresh() ?? $task;
  }

  public function update(Task $task, array $attributes): Task
  {
    $task->fill($attributes);
    $task->save();

    return $task->fresh() ?? $task;
  }

  public function delete(Task $task): bool
  {
    return (bool) $task->delete();
  }

  private function escapeLike(string $value): string
  {
    return str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $value);
  }
}
