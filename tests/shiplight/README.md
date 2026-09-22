# School Management System - Shiplight E2E Test Suite

## Test Execution Status
- **Started**: ${new Date().toISOString()}
- **Status**: PREPARING - Waiting for Flutter app to start
- **Current URL**: TBD (waiting for app startup)
- **MCP Status**: FIXED - Configuration updated to use correct npx path

## Test Categories
1. **Authentication Tests** (AUTH-001 to AUTH-009)
2. **System Health Tests** (SYS-001)
3. **Super User Tests** (SU-001+)
4. **Administrator Tests** (ADM-001+)  
5. **Teacher Tests** (TCH-001+)
6. **Head Teacher Tests** (HT-001+)
7. **Accountant Tests** (ACC-001+)
8. **Guardian Tests** (GDN-001+)
9. **Permission Tests** (PERM-001+)

## Execution Order
Tests will be executed in the order above, with each role's tests run sequentially.

## User Accounts for Testing
- **Super User**: super@schoolsystem.test
- **Administrator**: admin@schoolsystem.test  
- **Teacher**: teacher@schoolsystem.test
- **Head Teacher**: headteacher@schoolsystem.test
- **Accountant**: accountant@schoolsystem.test
- **Guardian**: guardian@schoolsystem.test

All accounts use password: `Test123!`

## Next Steps
1. Wait for Flutter app to complete startup
2. Extract localhost URL from Flutter output
3. Begin test execution with AUTH-001