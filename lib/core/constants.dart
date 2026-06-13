// ---------------------------------------------------------------------------
// Environment variables — pass via --dart-define at build/run time:
//   --dart-define=SUPABASE_URL=https://xxx.supabase.co
//   --dart-define=SUPABASE_ANON_KEY=eyJ...
// ---------------------------------------------------------------------------
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

// ---------------------------------------------------------------------------
// Table names
// ---------------------------------------------------------------------------
const String kTableProfiles = 'profiles';
const String kTableCategories = 'categories';
const String kTableEquipment = 'equipment';
const String kTableClients = 'clients';
const String kTableRentals = 'rentals';
const String kTableRentalItems = 'rental_items';

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
