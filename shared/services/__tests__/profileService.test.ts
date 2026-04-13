import { describe, it, expect, beforeEach, vi } from 'vitest';
import { supabase } from '@/lib/supabase';
import {
  getProfile,
  getCurrentProfile,
  updateProfile,
  uploadAvatar,
} from '../profileService';

// Mock Supabase client
vi.mock('@/lib/supabase', () => ({
  supabase: {
    auth: {
      getUser: vi.fn(),
    },
    from: vi.fn(),
    storage: {
      from: vi.fn(),
    },
  },
}));

describe('profileService', () => {
  const mockUser = {
    id: 'user-123',
    email: 'test@example.com',
  };

  const mockProfile = {
    id: 'user-123',
    email: 'test@example.com',
    username: 'testuser',
    discriminator: '1234',
    avatar: null,
    banner: null,
    bio: 'Test bio',
    status: 'online' as const,
    custom_status: null,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getProfile', () => {
    it('should fetch a user profile by ID', async () => {
      const profileQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockProfile,
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(profileQuery as any);

      const result = await getProfile('user-123');

      expect(result).toEqual(mockProfile);
      expect(supabase.from).toHaveBeenCalledWith('profiles');
    });

    it('should throw error if profile not found', async () => {
      const profileQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(profileQuery as any);

      await expect(getProfile('user-123')).rejects.toThrow('Profile not found');
    });

    it('should throw error on query failure', async () => {
      const profileQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'Database error' },
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(profileQuery as any);

      await expect(getProfile('user-123')).rejects.toThrow(
        'Failed to fetch profile: Database error'
      );
    });
  });

  describe('getCurrentProfile', () => {
    it('should fetch the current authenticated user profile', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const profileQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: mockProfile,
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(profileQuery as any);

      const result = await getCurrentProfile();

      expect(result).toEqual(mockProfile);
      expect(supabase.auth.getUser).toHaveBeenCalled();
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(getCurrentProfile()).rejects.toThrow('User not authenticated');
    });
  });

  describe('updateProfile', () => {
    it('should update user profile successfully', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const updateQuery = {
        update: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { ...mockProfile, bio: 'Updated bio' },
          error: null,
        }),
      };

      vi.mocked(supabase.from).mockReturnValueOnce(updateQuery as any);

      const result = await updateProfile({ bio: 'Updated bio' });

      expect(result.bio).toBe('Updated bio');
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(updateProfile({ bio: 'Test' })).rejects.toThrow(
        'User not authenticated'
      );
    });

    it('should validate username length', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      await expect(updateProfile({ username: '' })).rejects.toThrow(
        'Username cannot be empty'
      );

      await expect(updateProfile({ username: 'a' })).rejects.toThrow(
        'Username must be at least 2 characters'
      );

      await expect(updateProfile({ username: 'a'.repeat(33) })).rejects.toThrow(
        'Username must be 32 characters or less'
      );
    });

    it('should validate username format', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      await expect(updateProfile({ username: 'test user' })).rejects.toThrow(
        'Username can only contain letters, numbers, underscores, and hyphens'
      );

      await expect(updateProfile({ username: 'test@user' })).rejects.toThrow(
        'Username can only contain letters, numbers, underscores, and hyphens'
      );
    });

    it('should check username uniqueness', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Mock current profile query
      const currentProfileQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { discriminator: '1234' },
          error: null,
        }),
      };

      // Mock existing user check
      const existingUserQuery = {
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        neq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { id: 'other-user' },
          error: null,
        }),
      };

      vi.mocked(supabase.from)
        .mockReturnValueOnce(currentProfileQuery as any)
        .mockReturnValueOnce(existingUserQuery as any);

      await expect(updateProfile({ username: 'existinguser' })).rejects.toThrow(
        'Username is already taken'
      );
    });

    it('should validate bio length', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      await expect(updateProfile({ bio: 'a'.repeat(191) })).rejects.toThrow(
        'Bio must be 190 characters or less'
      );
    });

    it('should validate custom status length', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      await expect(
        updateProfile({ custom_status: 'a'.repeat(129) })
      ).rejects.toThrow('Custom status must be 128 characters or less');
    });
  });

  describe('uploadAvatar', () => {
    const mockFile = new File(['test'], 'avatar.png', { type: 'image/png' });

    it('should upload avatar successfully', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const mockPublicUrl = 'https://example.com/avatars/user-123-123456.png';

      // Mock storage upload
      const storageUpload = {
        upload: vi.fn().mockResolvedValue({
          data: { path: 'avatars/user-123-123456.png' },
          error: null,
        }),
      };

      // Mock getPublicUrl
      const storageGetUrl = {
        getPublicUrl: vi.fn().mockReturnValue({
          data: { publicUrl: mockPublicUrl },
        }),
      };

      // Mock profile update
      const profileUpdate = {
        update: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      vi.mocked(supabase.storage.from)
        .mockReturnValueOnce(storageUpload as any)
        .mockReturnValueOnce(storageGetUrl as any);

      vi.mocked(supabase.from).mockReturnValueOnce(profileUpdate as any);

      const result = await uploadAvatar(mockFile);

      expect(result.url).toBe(mockPublicUrl);
      expect(result.path).toContain('avatars/user-123-');
    });

    it('should throw error if user is not authenticated', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: null },
        error: null,
      } as any);

      await expect(uploadAvatar(mockFile)).rejects.toThrow('User not authenticated');
    });

    it('should validate file type', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const invalidFile = new File(['test'], 'avatar.txt', { type: 'text/plain' });

      await expect(uploadAvatar(invalidFile)).rejects.toThrow(
        'Invalid file type. Only JPEG, PNG, GIF, and WebP images are allowed'
      );
    });

    it('should validate file size', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      // Create a mock file larger than 5MB
      const largeFile = new File(['x'.repeat(6 * 1024 * 1024)], 'large.png', {
        type: 'image/png',
      });

      await expect(uploadAvatar(largeFile)).rejects.toThrow(
        'File size exceeds 5MB limit'
      );
    });

    it('should handle upload errors', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const storageUpload = {
        upload: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'Upload failed' },
        }),
      };

      vi.mocked(supabase.storage.from).mockReturnValueOnce(storageUpload as any);

      await expect(uploadAvatar(mockFile)).rejects.toThrow(
        'Failed to upload avatar: Upload failed'
      );
    });

    it('should rollback upload if profile update fails', async () => {
      vi.mocked(supabase.auth.getUser).mockResolvedValue({
        data: { user: mockUser },
        error: null,
      } as any);

      const mockPath = 'avatars/user-123-123456.png';

      // Mock storage upload
      const storageUpload = {
        upload: vi.fn().mockResolvedValue({
          data: { path: mockPath },
          error: null,
        }),
      };

      // Mock getPublicUrl
      const storageGetUrl = {
        getPublicUrl: vi.fn().mockReturnValue({
          data: { publicUrl: 'https://example.com/avatar.png' },
        }),
      };

      // Mock storage remove for rollback
      const storageRemove = {
        remove: vi.fn().mockResolvedValue({
          data: null,
          error: null,
        }),
      };

      // Mock profile update failure
      const profileUpdate = {
        update: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({
          data: null,
          error: { message: 'Update failed' },
        }),
      };

      vi.mocked(supabase.storage.from)
        .mockReturnValueOnce(storageUpload as any)
        .mockReturnValueOnce(storageGetUrl as any)
        .mockReturnValueOnce(storageRemove as any);

      vi.mocked(supabase.from).mockReturnValueOnce(profileUpdate as any);

      await expect(uploadAvatar(mockFile)).rejects.toThrow(
        'Failed to update profile with avatar: Update failed'
      );

      // Verify rollback was attempted
      expect(storageRemove.remove).toHaveBeenCalledWith([mockPath]);
    });
  });
});
