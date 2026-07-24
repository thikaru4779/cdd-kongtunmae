// Hand-written subset of the Supabase schema — covers only the tables the app
// code touches so far (Phases 2-4). Regenerate the full file once Docker is
// available: `supabase gen types typescript --db-url <url> > types/database.types.ts`
//
// Every table needs `Relationships: []` and the schema needs `Views`/`Functions`
// even when empty — @supabase/postgrest-js's GenericTable/GenericSchema
// constraints require those keys to exist or every query collapses to `never`.

export type UserRole =
  | 'MEMBER'
  | 'COMMITTEE'
  | 'STAFF'
  | 'DISTRICT_HEAD'
  | 'PROVINCE_MGR'
  | 'PROVINCE_HEAD'
  | 'GOVERNOR';

export interface Database {
  public: {
    Tables: {
      users: {
        Row: {
          id: string;
          line_user_id: string;
          display_name: string | null;
          phone: string | null;
          role: UserRole;
          village_id: number | null;
          district_id: number | null;
          status: 'ACTIVE' | 'SUSPENDED';
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          line_user_id: string;
          display_name?: string | null;
          phone?: string | null;
          role?: UserRole;
          village_id?: number | null;
          district_id?: number | null;
          status?: 'ACTIVE' | 'SUSPENDED';
        };
        Update: Partial<Database['public']['Tables']['users']['Insert']>;
        Relationships: [];
      };
      districts: {
        Row: {
          id: number;
          province_id: number;
          code: string;
          name_th: string;
        };
        Insert: Partial<Database['public']['Tables']['districts']['Row']>;
        Update: Partial<Database['public']['Tables']['districts']['Row']>;
        Relationships: [];
      };
      subdistricts: {
        Row: {
          id: number;
          district_id: number;
          code: string;
          name_th: string;
        };
        Insert: Partial<Database['public']['Tables']['subdistricts']['Row']>;
        Update: Partial<Database['public']['Tables']['subdistricts']['Row']>;
        Relationships: [];
      };
      village_master: {
        Row: {
          id: number;
          subdistrict_id: number;
          village_code: string;
          moo_no: number;
          name_th: string;
          lat: number | null;
          lng: number | null;
          founding_year: number | null;
          is_active: boolean;
          created_at: string;
        };
        Insert: Partial<Database['public']['Tables']['village_master']['Row']>;
        Update: Partial<Database['public']['Tables']['village_master']['Row']>;
        Relationships: [];
      };
      activities_type: {
        Row: {
          id: number;
          code: string;
          name_th: string;
          category_th: string;
          score: number;
          bonus_point: number;
          weight: number;
          innovation_point: number;
          mom_quest_step_no: number | null;
          is_active: boolean;
        };
        Insert: Partial<Database['public']['Tables']['activities_type']['Row']>;
        Update: Partial<Database['public']['Tables']['activities_type']['Row']>;
        Relationships: [];
      };
      activities: {
        Row: {
          id: number;
          village_id: number;
          district_id: number;
          activity_type_id: number;
          activity_date: string;
          recorded_by: string;
          lat: number | null;
          lng: number | null;
          notes: string | null;
          score_frozen: number;
          innovation_point_frozen: number;
          bonus_point_frozen: number;
          weight_frozen: number;
          total_score_frozen: number;
          status: 'SUBMITTED' | 'SPOT_CHECK_FLAGGED' | 'VERIFIED' | 'REJECTED';
          created_at: string;
          updated_at: string;
        };
        Insert: {
          village_id: number;
          activity_type_id: number;
          activity_date: string;
          recorded_by: string;
          lat?: number | null;
          lng?: number | null;
          notes?: string | null;
          score_frozen: number;
          innovation_point_frozen: number;
          bonus_point_frozen: number;
          weight_frozen: number;
        };
        Update: Partial<Database['public']['Tables']['activities']['Insert']>;
        Relationships: [];
      };
      staff_whitelist: {
        Row: {
          id: number;
          phone: string;
          role: UserRole;
          district_id: number | null;
          is_used: boolean;
          created_at: string;
        };
        Insert: Partial<Database['public']['Tables']['staff_whitelist']['Row']>;
        Update: Partial<Database['public']['Tables']['staff_whitelist']['Row']>;
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}
