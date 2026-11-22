<?php

namespace Tests\Feature\Api\V1\Order;

use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderPaginationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_paginated_orders_are_complete_and_not_duplicated(): void
    {
        $user = User::factory()->create(['status' => 'active']);

        for ($i = 0; $i < 5; $i++) {
            $this->createOrderFor($user);
        }

        Sanctum::actingAs($user);

        $ids = [];

        for ($page = 1; $page <= 3; $page++) {
            $response = $this
                ->getJson("/api/v1/orders?page={$page}&per_page=2")
                ->assertOk()
                ->assertJsonPath('meta.current_page', $page)
                ->assertJsonPath('meta.total', 5);

            $expectedCount = $page === 3 ? 1 : 2;

            $response->assertJsonCount($expectedCount, 'data');

            foreach ($response->json('data') as $order) {
                $ids[] = $order['id'];
                $this->assertSame(
                    'pending_responses',
                    $order['aggregate_status'],
                );
            }
        }

        $this->assertCount(5, $ids);
        $this->assertCount(5, array_unique($ids));
    }

    public function test_pagination_never_exposes_another_users_orders(): void
    {
        $user = User::factory()->create(['status' => 'active']);
        $other = User::factory()->create(['status' => 'active']);

        $visible = $this->createOrderFor($user);
        $hidden = $this->createOrderFor($other);

        Sanctum::actingAs($user);

        $this
            ->getJson('/api/v1/orders?page=1&per_page=20')
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.id', $visible->id)
            ->assertJsonMissing(['id' => $hidden->id]);
    }

    public function test_invalid_pagination_parameters_are_rejected(): void
    {
        $user = User::factory()->create(['status' => 'active']);
        Sanctum::actingAs($user);

        foreach ([
            '?page=0',
            '?page=abc',
            '?per_page=0',
            '?per_page=101',
            '?per_page=abc',
        ] as $query) {
            $this
                ->getJson('/api/v1/orders' . $query)
                ->assertUnprocessable();
        }
    }

    public function test_legacy_response_remains_unchanged(): void
    {
        $user = User::factory()->create(['status' => 'active']);

        $this->createOrderFor($user);
        $this->createOrderFor($user);

        Sanctum::actingAs($user);

        $this
            ->getJson('/api/v1/orders')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonMissingPath('meta');
    }

    private function createOrderFor(User $user): Order
    {
        return Order::query()->create([
            'user_id' => $user->id,
            'idempotency_key' => (string) Str::uuid(),
            'idempotency_payload_hash' => hash(
                'sha256',
                (string) Str::uuid(),
            ),
            'status' => 'pending',
            'notes' => 'Pagination test order',
        ]);
    }
}