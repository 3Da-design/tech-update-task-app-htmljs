<?php

return [
  'default_user_email' => env('DEFAULT_TASK_USER_EMAIL', 'test@example.com'),
  'status_values' => [0, 1, 2],
  'status_labels' => [
    0 => 'todo',
    1 => 'in_progress',
    2 => 'done',
  ],
];
