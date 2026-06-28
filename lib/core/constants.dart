// ---------------------------------------------------------------------------
// MCP API — pass via --dart-define at build/run time:
//   --dart-define=MCP_BASE_URL=http://localhost:3001
//   --dart-define=MCP_API_VERSION=v1
// ---------------------------------------------------------------------------
const mcpBaseUrl = String.fromEnvironment(
  'MCP_BASE_URL',
  defaultValue: 'http://localhost:3001',
);
const mcpApiVersion = String.fromEnvironment(
  'MCP_API_VERSION',
  defaultValue: 'v1',
);
/// Optional — required as X-Api-Key for warehouse routes when MCP server sets MCP_API_KEY.
const mcpApiKey = String.fromEnvironment('MCP_API_KEY');

// ---------------------------------------------------------------------------
// Equipment status values
// ---------------------------------------------------------------------------
const String kStatusAvailable = 'available';
const String kStatusRented = 'rented';
const String kStatusMaintenance = 'maintenance';
const String kStatusRetired = 'retired';

// ---------------------------------------------------------------------------
// Rental status values
// ---------------------------------------------------------------------------
const String kRentalStatusActive = 'active';
const String kRentalStatusReturned = 'returned';
const String kRentalStatusOverdue = 'overdue';
const String kRentalStatusCancelled = 'cancelled';
