<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * S1: Web タスクルートは削除済み。
 * タスク CRUD は API 経由に一本化されたため、
 * ここではリダイレクトと認証ガードのみ検証する。
 */
class TaskWebTest extends TestCase
{
  use RefreshDatabase;

  private User $user;

  protected function setUp(): void
  {
    parent::setUp();

    $this->user = User::factory()->create();
  }

  public function test_root_redirects_to_html_app(): void
  {
    $response = $this->get('/');

    $response->assertRedirect('/app/tasks.html');
  }

  public function test_dashboard_redirects_to_html_app_for_authenticated_user(): void
  {
    $response = $this->actingAs($this->user)->get('/dashboard');

    $response->assertRedirect('/app/tasks.html');
  }

  public function test_guest_is_redirected_from_dashboard_to_login(): void
  {
    $response = $this->get('/dashboard');

    $response->assertRedirect('/login');
  }
}
