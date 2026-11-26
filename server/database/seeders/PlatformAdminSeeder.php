<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use RuntimeException;

final class PlatformAdminSeeder extends Seeder
{
    private const USERNAME = 'admin2026';
    private const ROLE_CODE = 'platform_admin';

    public function run(): void
    {
        if (getenv('TALBYTK_PLATFORM_ADMIN_SEED_ENABLED') !== 'true') {
            throw new RuntimeException(
                'Platform admin seeding requires explicit opt-in.'
            );
        }

        $password = getenv('TALBYTK_PLATFORM_ADMIN_PASSWORD');

        if (
            ! is_string($password)
            || strlen($password) < 16
            || strlen($password) > 72
        ) {
            throw new RuntimeException(
                'Platform admin password must be between 16 and 72 bytes.'
            );
        }

        $displayName = getenv('TALBYTK_PLATFORM_ADMIN_DISPLAY_NAME');

        $displayName = is_string($displayName)
            && trim($displayName) !== ''
                ? trim($displayName)
                : 'مدير منصة Talbytk';

        $created = DB::transaction(function () use (
            $password,
            $displayName
        ): bool {
            $existing = User::withTrashed()
                ->whereRaw('LOWER(username) = ?', [self::USERNAME])
                ->lockForUpdate()
                ->first();

            if ($existing !== null) {
                $hasActiveAssignment = DB::table(
                    'platform_role_assignments'
                )
                    ->where('user_id', $existing->getKey())
                    ->where('role_code', self::ROLE_CODE)
                    ->whereNull('revoked_at')
                    ->exists();

                if (
                    $existing->trashed()
                    || $existing->status !== 'active'
                    || ! $hasActiveAssignment
                ) {
                    throw new RuntimeException(
                        'Username admin2026 already exists but is not an active platform administrator. No changes made.'
                    );
                }

                return false;
            }

            $user = User::query()->create([
                'username' => self::USERNAME,
                'display_name' => $displayName,
                'password' => $password,
                'status' => 'active',
            ]);

            DB::table('platform_role_assignments')->insert([
                'user_id' => $user->id,
                'role_code' => self::ROLE_CODE,
                'granted_by_user_id' => null,
                'granted_at' => now(),
                'revoked_at' => null,
            ]);

            return true;
        });

        $this->command?->info(
            $created
                ? 'Platform admin created successfully.'
                : 'Platform admin already exists. No changes made.'
        );
    }
}