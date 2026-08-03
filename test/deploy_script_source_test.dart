import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production deploy promotes both aliases and verifies public assets',
      () {
    final script = File('scripts/deploy.sh').readAsStringSync();
    final windowsScript = File('scripts/deploy.ps1').readAsStringSync();
    final vercelBuild = File('scripts/vercel-build.sh').readAsStringSync();
    final gitIgnore = File('.gitignore').readAsStringSync();
    final vercelIgnore = File('.vercelignore').readAsStringSync();
    final webWorkflow =
        File('.github/workflows/web-release.yml').readAsStringSync();
    final workflow =
        File('.github/workflows/flutter-quality.yml').readAsStringSync();

    expect(script, contains('vercel alias set'));
    expect(script, contains('fisher-go.app'));
    expect(script, contains('www.fisher-go.app'));
    expect(script, contains('tool/verify_deployed_web.dart'));
    expect(script, contains(r'--release-id="$RELEASE_ID"'));
    expect(script, contains('DEPLOYMENT_URL'));
    expect(script, contains('FISHERGO_PUBLIC_URL'));
    expect(script, contains('FISHERGO_PUBLIC_ALIAS_URL'));
    expect(script, contains('FISHERGO_RELEASE_ID'));
    expect(script, contains(r': "${VERCEL_TOKEN:?'));
    expect(script, contains(r': "${SUPABASE_URL:?'));
    expect(script, contains(r': "${SUPABASE_ANON_KEY:?'));
    expect(script, contains('tool/verify_public_release_config.dart'));
    expect(script, contains('--build-env="SUPABASE_URL='));
    expect(script, contains('--build-env="SUPABASE_ANON_KEY='));
    expect(script, contains('--build-env="FISHERGO_DEPLOY_RELEASE_ID='));
    expect(script, contains('--build-env="FISHERGO_RELEASE_ID='));
    expect(script, contains('--build-env="FISHERGO_GIT_SHA='));
    expect(script, contains('.fishergo-deploy-release-id'));
    expect(script, contains('PRIMARY_DOMAIN != "fisher-go.app"'));
    expect(script, contains('ALIAS_DOMAIN != "www.fisher-go.app"'));
    expect(windowsScript, contains(r'[switch]$PromoteProduction'));
    expect(windowsScript, contains(r'if (-not $PromoteProduction)'));
    expect(
      windowsScript.indexOf(r'if (-not $PromoteProduction)'),
      lessThan(windowsScript.indexOf('Import-DotEnv')),
    );
    expect(windowsScript, contains('--prod'));
    expect(windowsScript, contains('fisher-go.app'));
    expect(windowsScript, contains('www.fisher-go.app'));
    expect(windowsScript, contains('vercel alias set'));
    expect(windowsScript,
        contains('tool/check_client_artifacts_for_secrets.dart'));
    expect(windowsScript, contains('tool/verify_deployed_web.dart'));
    expect(windowsScript, contains('tool/verify_public_release_config.dart'));
    expect(windowsScript, contains('tool/write_release_manifest.dart'));
    expect(windowsScript, contains("'--build-env'"));
    expect(windowsScript, contains(r'SUPABASE_URL=$supabaseUrl'));
    expect(windowsScript, contains(r'FISHERGO_DEPLOY_RELEASE_ID=$releaseId'));
    expect(windowsScript, contains(r'FISHERGO_RELEASE_ID=$releaseId'));
    expect(windowsScript, contains('.fishergo-deploy-release-id'));
    expect(windowsScript, isNot(contains(r'Write-Host $vercelToken')));
    expect(webWorkflow, contains('workflow_dispatch:'));
    expect(webWorkflow, contains('environment: fishergo-web-release'));
    expect(webWorkflow, contains('secrets.VERCEL_TOKEN'));
    expect(webWorkflow, contains('secrets.SUPABASE_URL'));
    expect(webWorkflow, contains('secrets.SUPABASE_ANON_KEY'));
    expect(webWorkflow, contains('FISHERGO_PUBLIC_URL: https://fisher-go.app'));
    expect(webWorkflow,
        contains('FISHERGO_PUBLIC_ALIAS_URL: https://www.fisher-go.app'));
    expect(webWorkflow, contains('bash scripts/deploy.sh'));
    expect(webWorkflow, contains('FISHERGO_PRIVACY_URL'));
    expect(webWorkflow, contains('FISHERGO_SUPPORT_EMAIL'));
    expect(webWorkflow, contains('FISHERGO_RELEASE_ID'));
    expect(vercelBuild, contains('FISHERGO_RELEASE_ID'));
    expect(vercelBuild, contains('FISHERGO_DEPLOY_RELEASE_ID'));
    expect(vercelBuild, contains('.fishergo-deploy-release-id'));
    expect(gitIgnore, isNot(contains('.fishergo-deploy-release-id')));
    expect(gitIgnore, contains('/node_modules/'));
    expect(gitIgnore, contains('/tmp/'));
    expect(gitIgnore, contains('/output/'));
    expect(gitIgnore, contains('/.playwright-cli/'));
    expect(vercelIgnore, isNot(contains('.fishergo-deploy-release-id')));
    expect(script, contains('--dart-define=FISHERGO_MAPLIBRE=true'));
    expect(script, contains('--dart-define=FISHERGO_PRIVACY_URL='));
    expect(script, contains('--dart-define=FISHERGO_SUPPORT_EMAIL='));
    expect(
        script, contains('--dart-define=FISHERGO_ACCOUNT_DELETION_ENABLED='));
    expect(script, contains('--build-env="FISHERGO_ACCOUNT_DELETION_ENABLED='));
    expect(vercelBuild, contains('--dart-define=FISHERGO_MAPLIBRE=true'));
    expect(vercelBuild, contains('--dart-define=FISHERGO_PRIVACY_URL='));
    expect(vercelBuild, contains('--dart-define=FISHERGO_SUPPORT_EMAIL='));
    expect(
      vercelBuild,
      contains('--dart-define=FISHERGO_ACCOUNT_DELETION_ENABLED='),
    );
    expect(
      windowsScript,
      contains('--dart-define=FISHERGO_ACCOUNT_DELETION_ENABLED='),
    );
    expect(
      windowsScript,
      contains(r'FISHERGO_ACCOUNT_DELETION_ENABLED=$accountDeletionEnabled'),
    );
    expect(vercelBuild, contains('tool/write_release_manifest.dart'));
    expect(workflow, contains('--dart-define=FISHERGO_MAPLIBRE=true'));
    expect(
      workflow,
      contains('pwsh -NoProfile -File tool/run_android_integration_smoke.ps1'),
    );
    expect(workflow, contains('-ClearAppData'));
    expect(workflow, contains('-TimeoutSeconds 240'));
    expect(workflow, contains('-TestFile startup_auth_flow_test.dart'));
    expect(workflow, contains('-TestFile fishing_minigame_flow_test.dart'));
    expect(workflow, contains('-TestFile offline_reconnect_flow_test.dart'));
    expect(workflow, contains('-TestFile daily_task_reward_flow_test.dart'));
  });

  test('Vercel production builds require public Supabase configuration', () {
    final vercelBuild = File('scripts/vercel-build.sh').readAsStringSync();

    expect(vercelBuild, contains('VERCEL_ENV'));
    expect(vercelBuild, contains('FISHERGO_REQUIRE_SUPABASE'));
    expect(vercelBuild, contains(r': "${SUPABASE_URL:?'));
    expect(vercelBuild, contains(r': "${SUPABASE_ANON_KEY:?'));
    expect(vercelBuild, contains('production'));
    expect(vercelBuild, contains('FISHERGO_PRIVACY_URL'));
    expect(vercelBuild, contains('FISHERGO_SUPPORT_EMAIL'));
    expect(vercelBuild, contains('tool/verify_public_release_config.dart'));
  });

  test('production deploys require a clean, traceable Git worktree', () {
    final script = File('scripts/deploy.sh').readAsStringSync();
    final windowsScript = File('scripts/deploy.ps1').readAsStringSync();

    expect(script, contains('git status --porcelain'));
    expect(script,
        contains('Production deployment requires a clean Git worktree'));
    expect(script.indexOf('git status --porcelain'),
        lessThan(script.indexOf('if [ -f .env ]')));
    expect(windowsScript, contains('git status --porcelain'));
    expect(windowsScript,
        contains('Production deployment requires a clean Git worktree'));
    expect(windowsScript.indexOf('git status --porcelain'),
        lessThan(windowsScript.indexOf('function Import-DotEnv')));
  });
}
