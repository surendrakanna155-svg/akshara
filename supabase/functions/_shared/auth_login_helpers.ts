import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export interface StudentLoginTarget {
  studentId: string;
  phone: string;
  userId: string;
  organizationId: string;
}

export async function resolveStudentLoginTargetWithClient(
  client: SupabaseClient,
  schoolId: string,
  studentIdentifier: string,
): Promise<StudentLoginTarget | null> {
  const { data: students, error } = await client
    .from("students")
    .select("id,user_id,organization_id,student_code,student_profiles(admission_number),users!students_user_id_fkey(phone)")
    .eq("school_id", schoolId)
    .not("user_id", "is", null);

  if (error || !students?.length) return null;

  const match = students.find((row) => {
    const profiles = row.student_profiles as Array<{ admission_number?: string }> | null;
    const admission = profiles?.[0]?.admission_number;
    return row.student_code === studentIdentifier || admission === studentIdentifier;
  });
  if (!match?.user_id) return null;

  const users = match.users as { phone?: string } | null;
  const phone = users?.phone;
  if (!phone) return null;

  return {
    studentId: match.id as string,
    phone,
    userId: match.user_id as string,
    organizationId: match.organization_id as string,
  };
}
