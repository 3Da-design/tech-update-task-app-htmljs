<?php

namespace App\Repositories\Contracts;

use App\Models\Task;
use Illuminate\Database\Eloquent\Collection;

interface TaskRepositoryInterface
{
  /**
   * @param  array{title?: string, status?: int, due_date_sort?: string}  $filters
   * @return Collection<int, Task>
   */
  public function getFiltered(int $userId, array $filters = []): Collection;

  public function findById(int $userId, int $taskId): ?Task;

  /**
   * @param  array<string, mixed>  $attributes
   */
  public function create(int $userId, array $attributes): Task;

  /**
   * @param  array<string, mixed>  $attributes
   */
  public function update(Task $task, array $attributes): Task;

  public function delete(Task $task): bool;
}
