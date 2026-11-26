<?php

namespace Tests\Feature\Platform;

use App\Models\User;
use Database\Seeders\PlatformAdminSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Hash;
use RuntimeException;
use Tests\TestCase;

class PlatformAdminSeederTest extends TestCase
{
    use RefreshDatabase;

    private array $previousEnvironment = [];

    private const TEST_PASSWORD =
        'Test-Only-Platform-Admin-2026!';

    protected function setUp(): void
    {
        parent::setUp();

        foreach ([
            'TALBYTK_PLATFORM_ADMIN_SEED_ENABLED',
            'TALBYTK_PLATFORM_ADMIN_PASSWORD',
        ] as $key) {
            $this->previousEnvironment[$key] = getenv($key);
        }

        putenv('TALBYTK_PLATFORM_ADMIN_SEED_ENABLED=true');

        putenv(
            'TALBYTK_PLATFORM_ADMIN_PASSWORD='.self::TEST_PASSWORD
        );
    }

    protected function tearDown(): void
    {
        foreach ($this->previousEnvironment as $key => $value) {
            if ($value === false) {
                putenv($key);
            } else {
                putenv($key.'='.$value);
            }
        }

        parent::tearDown();
    }

    public function test_it_creates_an_independent_active_platform_admin(): void
    {
        $this->seed(PlatformAdminSeeder::class);

        $user = User::query()
            ->where('username', 'admin2026')
            ->firstOrFail();

        $this->assertSame('active', $user->status);

        $this->assertTrue(
            Hash::check(self::TEST_PASSWORD, $user->password)
        );

        $assignment = DB::table('platform_role_assignments')
            ->where('user_id', $user->id)
            ->where('role_code', 'platform_admin')
            ->first();

        $this->assertNotNull($assignment);
        $this->assertNull($assignment->revoked_at);
        $this->assertNull($assignment->granted_by_user_id);

        $this->assertTrue(
            Gate::forUser($user)->allows('manageUsers')
        );

        $this->assertTrue(
            Gate::forUser($user)->allows('reviewSupplierApprovals')
        );
    }

    public function test_it_is_idempotent_and_does_not_change_password(): void
    {
        $this->seed(PlatformAdminSeeder::class);

        $user = User::query()
            ->where('username', 'admin2026')
            ->firstOrFail();

        $originalHash = $user->password;

        putenv(
            'TALBYTK_PLATFORM_ADMIN_PASSWORD=Another-Test-Password-2026!'
        );

        $this->seed(PlatformAdminSeeder::class);

        $this->assertSame(
            $originalHash,
            $user->fresh()->password
        );

        $this->assertDatabaseCount(
            'platform_role_assignments',
            1
        );
    }

    public function test_it_refuses_to_promote_an_existing_regular_user(): void
    {
        $user = User::factory()->create([
            'username' => 'admin2026',
            'password' => 'Existing-Account-Password-2026!',
            'status' => 'active',
        ]);

        $originalHash = $user->password;

        try {
            $this->seed(PlatformAdminSeeder::class);

            $this->fail(
                'Seeder must refuse to promote an existing user.'
            );
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString(
                'already exists',
                $exception->getMessage()
            );
        }

        $this->assertSame(
            $originalHash,
            $user->fresh()->password
        );

        $this->assertDatabaseMissing(
            'platform_role_assignments',
            ['user_id' => $user->id]
        );
    }

    public function test_it_requires_explicit_opt_in(): void
    {
        putenv('TALBYTK_PLATFORM_ADMIN_SEED_ENABLED');

        $this->expectException(RuntimeException::class);

        $this->seed(PlatformAdminSeeder::class);
    }
}
