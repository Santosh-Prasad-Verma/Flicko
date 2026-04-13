export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.1"
  }
  public: {
    Tables: {
      activities: {
        Row: {
          created_at: string
          details: string | null
          enabled: boolean | null
          ends_at: string | null
          id: string
          metadata: Json | null
          name: string
          started_at: string
          state: string | null
          type: string
          user_id: string
        }
        Insert: {
          created_at?: string
          details?: string | null
          enabled?: boolean | null
          ends_at?: string | null
          id?: string
          metadata?: Json | null
          name: string
          started_at?: string
          state?: string | null
          type: string
          user_id: string
        }
        Update: {
          created_at?: string
          details?: string | null
          enabled?: boolean | null
          ends_at?: string | null
          id?: string
          metadata?: Json | null
          name?: string
          started_at?: string
          state?: string | null
          type?: string
          user_id?: string
        }
        Relationships: []
      }
      activity_participants: {
        Row: {
          created_at: string | null
          id: string
          session_id: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          session_id: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          session_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "activity_participants_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "activity_sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_participants_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_participants_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      activity_sessions: {
        Row: {
          activity_id: string
          channel_id: string
          created_at: string | null
          embed_url: string | null
          ended_at: string | null
          host_user_id: string
          id: string
          server_id: string
          started_at: string | null
          state: string
        }
        Insert: {
          activity_id: string
          channel_id: string
          created_at?: string | null
          embed_url?: string | null
          ended_at?: string | null
          host_user_id: string
          id?: string
          server_id: string
          started_at?: string | null
          state?: string
        }
        Update: {
          activity_id?: string
          channel_id?: string
          created_at?: string | null
          embed_url?: string | null
          ended_at?: string | null
          host_user_id?: string
          id?: string
          server_id?: string
          started_at?: string | null
          state?: string
        }
        Relationships: [
          {
            foreignKeyName: "activity_sessions_activity_id_fkey"
            columns: ["activity_id"]
            isOneToOne: false
            referencedRelation: "activities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_sessions_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_sessions_host_user_id_fkey"
            columns: ["host_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_sessions_host_user_id_fkey"
            columns: ["host_user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_sessions_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      announcements: {
        Row: {
          announcement_type: string
          author_id: string
          channel_id: string
          content: string
          created_at: string
          id: string
          is_pinned: boolean
          priority: number
          published_at: string | null
          scheduled_for: string | null
          server_id: string
          title: string
          updated_at: string
          view_count: number
        }
        Insert: {
          announcement_type?: string
          author_id: string
          channel_id: string
          content: string
          created_at?: string
          id?: string
          is_pinned?: boolean
          priority?: number
          published_at?: string | null
          scheduled_for?: string | null
          server_id: string
          title: string
          updated_at?: string
          view_count?: number
        }
        Update: {
          announcement_type?: string
          author_id?: string
          channel_id?: string
          content?: string
          created_at?: string
          id?: string
          is_pinned?: boolean
          priority?: number
          published_at?: string | null
          scheduled_for?: string | null
          server_id?: string
          title?: string
          updated_at?: string
          view_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "announcements_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "announcements_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      application_commands: {
        Row: {
          application_id: string
          created_at: string | null
          default_member_perms: number | null
          description: string
          dm_permission: boolean | null
          guild_id: string | null
          id: string
          name: string
          nsfw: boolean | null
          options: Json | null
          type: number | null
          version: number
        }
        Insert: {
          application_id?: string
          created_at?: string | null
          default_member_perms?: number | null
          description?: string
          dm_permission?: boolean | null
          guild_id?: string | null
          id?: string
          name: string
          nsfw?: boolean | null
          options?: Json | null
          type?: number | null
          version?: number
        }
        Update: {
          application_id?: string
          created_at?: string | null
          default_member_perms?: number | null
          description?: string
          dm_permission?: boolean | null
          guild_id?: string | null
          id?: string
          name?: string
          nsfw?: boolean | null
          options?: Json | null
          type?: number | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "application_commands_guild_id_fkey"
            columns: ["guild_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      attachments: {
        Row: {
          created_at: string
          filename: string
          height: number | null
          id: string
          is_malware: boolean
          message_id: string
          mime_type: string
          size: number
          url: string
          width: number | null
        }
        Insert: {
          created_at?: string
          filename: string
          height?: number | null
          id?: string
          is_malware?: boolean
          message_id: string
          mime_type: string
          size: number
          url: string
          width?: number | null
        }
        Update: {
          created_at?: string
          filename?: string
          height?: number | null
          id?: string
          is_malware?: boolean
          message_id?: string
          mime_type?: string
          size?: number
          url?: string
          width?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "attachments_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_log: {
        Row: {
          action: string
          changes: Json | null
          created_at: string
          id: string
          reason: string | null
          server_id: string
          target_id: string | null
          target_type: string
          user_id: string | null
        }
        Insert: {
          action: string
          changes?: Json | null
          created_at?: string
          id?: string
          reason?: string | null
          server_id: string
          target_id?: string | null
          target_type: string
          user_id?: string | null
        }
        Update: {
          action?: string
          changes?: Json | null
          created_at?: string
          id?: string
          reason?: string | null
          server_id?: string
          target_id?: string | null
          target_type?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      automod_rules: {
        Row: {
          action_config: Json
          action_type: string
          actions: Json | null
          created_at: string
          enabled: boolean
          exempt_channels: string[] | null
          exempt_roles: string[] | null
          id: string
          name: string
          server_id: string
          trigger_metadata: Json
          trigger_type: string
          updated_at: string
        }
        Insert: {
          action_config: Json
          action_type: string
          actions?: Json | null
          created_at?: string
          enabled?: boolean
          exempt_channels?: string[] | null
          exempt_roles?: string[] | null
          id?: string
          name: string
          server_id: string
          trigger_metadata: Json
          trigger_type: string
          updated_at?: string
        }
        Update: {
          action_config?: Json
          action_type?: string
          actions?: Json | null
          created_at?: string
          enabled?: boolean
          exempt_channels?: string[] | null
          exempt_roles?: string[] | null
          id?: string
          name?: string
          server_id?: string
          trigger_metadata?: Json
          trigger_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "auto_mod_rules_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      automod_settings: {
        Row: {
          caps_filter: boolean | null
          caps_threshold: number | null
          created_at: string | null
          duplicate_filter: boolean | null
          duplicate_threshold: number | null
          emoji_filter: boolean | null
          emoji_threshold: number | null
          enabled: boolean | null
          exempt_channels: string[] | null
          exempt_roles: string[] | null
          exempt_users: string[] | null
          invite_filter: boolean | null
          link_filter: boolean | null
          log_channel_id: string | null
          mention_filter: boolean | null
          mention_threshold: number | null
          server_id: string
          updated_at: string | null
        }
        Insert: {
          caps_filter?: boolean | null
          caps_threshold?: number | null
          created_at?: string | null
          duplicate_filter?: boolean | null
          duplicate_threshold?: number | null
          emoji_filter?: boolean | null
          emoji_threshold?: number | null
          enabled?: boolean | null
          exempt_channels?: string[] | null
          exempt_roles?: string[] | null
          exempt_users?: string[] | null
          invite_filter?: boolean | null
          link_filter?: boolean | null
          log_channel_id?: string | null
          mention_filter?: boolean | null
          mention_threshold?: number | null
          server_id: string
          updated_at?: string | null
        }
        Update: {
          caps_filter?: boolean | null
          caps_threshold?: number | null
          created_at?: string | null
          duplicate_filter?: boolean | null
          duplicate_threshold?: number | null
          emoji_filter?: boolean | null
          emoji_threshold?: number | null
          enabled?: boolean | null
          exempt_channels?: string[] | null
          exempt_roles?: string[] | null
          exempt_users?: string[] | null
          invite_filter?: boolean | null
          link_filter?: boolean | null
          log_channel_id?: string | null
          mention_filter?: boolean | null
          mention_threshold?: number | null
          server_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "automod_settings_log_channel_id_fkey"
            columns: ["log_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "automod_settings_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: true
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      bans: {
        Row: {
          banned_by: string
          created_at: string | null
          id: string
          reason: string | null
          server_id: string
          user_id: string
        }
        Insert: {
          banned_by: string
          created_at?: string | null
          id?: string
          reason?: string | null
          server_id: string
          user_id: string
        }
        Update: {
          banned_by?: string
          created_at?: string | null
          id?: string
          reason?: string | null
          server_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "server_bans_executor_id_fkey"
            columns: ["banned_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "server_bans_executor_id_fkey"
            columns: ["banned_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "server_bans_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "server_bans_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "server_bans_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      blocks: {
        Row: {
          blocked_id: string
          blocker_id: string
          created_at: string
        }
        Insert: {
          blocked_id: string
          blocker_id: string
          created_at?: string
        }
        Update: {
          blocked_id?: string
          blocker_id?: string
          created_at?: string
        }
        Relationships: []
      }
      bot_events: {
        Row: {
          bot_name: string
          created_at: string | null
          data: Json | null
          event_type: string
          id: string
          server_id: string
        }
        Insert: {
          bot_name: string
          created_at?: string | null
          data?: Json | null
          event_type: string
          id?: string
          server_id: string
        }
        Update: {
          bot_name?: string
          created_at?: string | null
          data?: Json | null
          event_type?: string
          id?: string
          server_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bot_events_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      bot_guilds: {
        Row: {
          bot_id: string
          enabled: boolean | null
          installed_at: string | null
          installed_by: string | null
          permissions: number | null
          server_id: string
        }
        Insert: {
          bot_id: string
          enabled?: boolean | null
          installed_at?: string | null
          installed_by?: string | null
          permissions?: number | null
          server_id: string
        }
        Update: {
          bot_id?: string
          enabled?: boolean | null
          installed_at?: string | null
          installed_by?: string | null
          permissions?: number | null
          server_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bot_guilds_bot_id_fkey"
            columns: ["bot_id"]
            isOneToOne: false
            referencedRelation: "bots"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bot_guilds_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      bots: {
        Row: {
          avatar_url: string | null
          created_at: string | null
          description: string | null
          enabled: boolean | null
          id: string
          is_system: boolean | null
          name: string
          owner_id: string | null
          permissions: Json | null
          token: string
          updated_at: string | null
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string | null
          description?: string | null
          enabled?: boolean | null
          id?: string
          is_system?: boolean | null
          name: string
          owner_id?: string | null
          permissions?: Json | null
          token?: string
          updated_at?: string | null
        }
        Update: {
          avatar_url?: string | null
          created_at?: string | null
          description?: string | null
          enabled?: boolean | null
          id?: string
          is_system?: boolean | null
          name?: string
          owner_id?: string | null
          permissions?: Json | null
          token?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      category_notification_settings: {
        Row: {
          category_id: string
          collapsed: boolean | null
          muted: boolean | null
          user_id: string
        }
        Insert: {
          category_id: string
          collapsed?: boolean | null
          muted?: boolean | null
          user_id: string
        }
        Update: {
          category_id?: string
          collapsed?: boolean | null
          muted?: boolean | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "category_notification_settings_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "category_notification_settings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "category_notification_settings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      channel_follows: {
        Row: {
          created_at: string | null
          id: string
          source_channel_id: string
          target_channel_id: string
          webhook_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          source_channel_id: string
          target_channel_id: string
          webhook_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          source_channel_id?: string
          target_channel_id?: string
          webhook_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "channel_follows_source_channel_id_fkey"
            columns: ["source_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "channel_follows_target_channel_id_fkey"
            columns: ["target_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "channel_follows_webhook_id_fkey"
            columns: ["webhook_id"]
            isOneToOne: false
            referencedRelation: "webhooks"
            referencedColumns: ["id"]
          },
        ]
      }
      channel_notification_settings: {
        Row: {
          channel_id: string
          level: string | null
          mute_until: string | null
          muted: boolean | null
          user_id: string
        }
        Insert: {
          channel_id: string
          level?: string | null
          mute_until?: string | null
          muted?: boolean | null
          user_id: string
        }
        Update: {
          channel_id?: string
          level?: string | null
          mute_until?: string | null
          muted?: boolean | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "channel_notification_settings_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "channel_notification_settings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "channel_notification_settings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      channel_read_states: {
        Row: {
          channel_id: string
          last_read_message_id: string | null
          last_viewed_at: string | null
          mention_count: number | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          channel_id: string
          last_read_message_id?: string | null
          last_viewed_at?: string | null
          mention_count?: number | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          channel_id?: string
          last_read_message_id?: string | null
          last_viewed_at?: string | null
          mention_count?: number | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "channel_read_states_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "channel_read_states_last_read_message_id_fkey"
            columns: ["last_read_message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "channel_read_states_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "channel_read_states_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      channels: {
        Row: {
          created_at: string | null
          default_thread_auto_archive: number | null
          id: string
          name: string
          nsfw: boolean | null
          parent_id: string | null
          position: number | null
          rate_limit_per_user: number | null
          server_id: string
          slowmode_seconds: number | null
          topic: string | null
          type: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          default_thread_auto_archive?: number | null
          id?: string
          name: string
          nsfw?: boolean | null
          parent_id?: string | null
          position?: number | null
          rate_limit_per_user?: number | null
          server_id: string
          slowmode_seconds?: number | null
          topic?: string | null
          type: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          default_thread_auto_archive?: number | null
          id?: string
          name?: string
          nsfw?: boolean | null
          parent_id?: string | null
          position?: number | null
          rate_limit_per_user?: number | null
          server_id?: string
          slowmode_seconds?: number | null
          topic?: string | null
          type?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "channels_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "channels_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      communities: {
        Row: {
          activity_score: number
          category: string | null
          created_at: string
          growth_rate: number
          is_discoverable: boolean
          is_verified: boolean
          member_count: number
          rules_channel_id: string | null
          server_id: string
          tags: string[] | null
          updated_at: string
        }
        Insert: {
          activity_score?: number
          category?: string | null
          created_at?: string
          growth_rate?: number
          is_discoverable?: boolean
          is_verified?: boolean
          member_count?: number
          rules_channel_id?: string | null
          server_id: string
          tags?: string[] | null
          updated_at?: string
        }
        Update: {
          activity_score?: number
          category?: string | null
          created_at?: string
          growth_rate?: number
          is_discoverable?: boolean
          is_verified?: boolean
          member_count?: number
          rules_channel_id?: string | null
          server_id?: string
          tags?: string[] | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "communities_rules_channel_id_fkey"
            columns: ["rules_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communities_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: true
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      connected_accounts: {
        Row: {
          access_token: string
          created_at: string
          external_user_id: string
          external_username: string | null
          id: string
          provider: string
          refresh_token: string | null
          token_expires_at: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          access_token: string
          created_at?: string
          external_user_id: string
          external_username?: string | null
          id?: string
          provider: string
          refresh_token?: string | null
          token_expires_at?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          access_token?: string
          created_at?: string
          external_user_id?: string
          external_username?: string | null
          id?: string
          provider?: string
          refresh_token?: string | null
          token_expires_at?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      direct_messages: {
        Row: {
          attachments: Json | null
          content: string
          created_at: string | null
          edited_at: string | null
          id: string
          recipient_id: string
          sender_id: string
        }
        Insert: {
          attachments?: Json | null
          content: string
          created_at?: string | null
          edited_at?: string | null
          id?: string
          recipient_id: string
          sender_id: string
        }
        Update: {
          attachments?: Json | null
          content?: string
          created_at?: string | null
          edited_at?: string | null
          id?: string
          recipient_id?: string
          sender_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "direct_messages_recipient_id_fkey"
            columns: ["recipient_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "direct_messages_recipient_id_fkey"
            columns: ["recipient_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "direct_messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "direct_messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      dm_calls: {
        Row: {
          answered_at: string | null
          call_type: string
          callee_id: string
          caller_id: string
          dm_id: string
          duration_seconds: number | null
          ended_at: string | null
          id: string
          room_name: string | null
          started_at: string | null
          status: string
        }
        Insert: {
          answered_at?: string | null
          call_type?: string
          callee_id: string
          caller_id: string
          dm_id: string
          duration_seconds?: number | null
          ended_at?: string | null
          id?: string
          room_name?: string | null
          started_at?: string | null
          status?: string
        }
        Update: {
          answered_at?: string | null
          call_type?: string
          callee_id?: string
          caller_id?: string
          dm_id?: string
          duration_seconds?: number | null
          ended_at?: string | null
          id?: string
          room_name?: string | null
          started_at?: string | null
          status?: string
        }
        Relationships: []
      }
      dm_messages: {
        Row: {
          author_id: string
          content: string
          conversation_id: string
          created_at: string
          edited_at: string | null
          id: string
          reply_to_id: string | null
          type: string
          updated_at: string
        }
        Insert: {
          author_id: string
          content: string
          conversation_id: string
          created_at?: string
          edited_at?: string | null
          id?: string
          reply_to_id?: string | null
          type?: string
          updated_at?: string
        }
        Update: {
          author_id?: string
          content?: string
          conversation_id?: string
          created_at?: string
          edited_at?: string | null
          id?: string
          reply_to_id?: string | null
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "dm_messages_reply_to_id_fkey"
            columns: ["reply_to_id"]
            isOneToOne: false
            referencedRelation: "dm_messages"
            referencedColumns: ["id"]
          },
        ]
      }
      dm_read_states: {
        Row: {
          conversation_id: string
          last_read_at: string
          last_read_message_id: string | null
          user_id: string
        }
        Insert: {
          conversation_id: string
          last_read_at?: string
          last_read_message_id?: string | null
          user_id: string
        }
        Update: {
          conversation_id?: string
          last_read_at?: string
          last_read_message_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "dm_read_states_last_read_message_id_fkey"
            columns: ["last_read_message_id"]
            isOneToOne: false
            referencedRelation: "dm_messages"
            referencedColumns: ["id"]
          },
        ]
      }
      drawing_strokes: {
        Row: {
          color: string
          coordinates: Json
          created_at: string
          id: string
          opacity: number
          screen_share_id: string
          tool: string
          user_id: string
          width: number
        }
        Insert: {
          color: string
          coordinates: Json
          created_at?: string
          id?: string
          opacity: number
          screen_share_id: string
          tool: string
          user_id: string
          width: number
        }
        Update: {
          color?: string
          coordinates?: Json
          created_at?: string
          id?: string
          opacity?: number
          screen_share_id?: string
          tool?: string
          user_id?: string
          width?: number
        }
        Relationships: [
          {
            foreignKeyName: "drawing_strokes_screen_share_id_fkey"
            columns: ["screen_share_id"]
            isOneToOne: false
            referencedRelation: "screen_shares"
            referencedColumns: ["id"]
          },
        ]
      }
      embeds: {
        Row: {
          color: number | null
          created_at: string
          description: string | null
          fields: Json | null
          id: string
          image_url: string | null
          message_id: string
          title: string | null
          type: string
          url: string | null
          video_url: string | null
        }
        Insert: {
          color?: number | null
          created_at?: string
          description?: string | null
          fields?: Json | null
          id?: string
          image_url?: string | null
          message_id: string
          title?: string | null
          type?: string
          url?: string | null
          video_url?: string | null
        }
        Update: {
          color?: number | null
          created_at?: string
          description?: string | null
          fields?: Json | null
          id?: string
          image_url?: string | null
          message_id?: string
          title?: string | null
          type?: string
          url?: string | null
          video_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "embeds_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      entitlements: {
        Row: {
          expires_at: string | null
          granted_at: string | null
          id: string
          revoked: boolean | null
          source: string
          source_id: string | null
          type: string
          user_id: string
        }
        Insert: {
          expires_at?: string | null
          granted_at?: string | null
          id?: string
          revoked?: boolean | null
          source?: string
          source_id?: string | null
          type: string
          user_id: string
        }
        Update: {
          expires_at?: string | null
          granted_at?: string | null
          id?: string
          revoked?: boolean | null
          source?: string
          source_id?: string | null
          type?: string
          user_id?: string
        }
        Relationships: []
      }
      event_rsvps: {
        Row: {
          event_id: string
          id: string | null
          joined_at: string
          status: string
          user_id: string
        }
        Insert: {
          event_id: string
          id?: string | null
          joined_at?: string
          status: string
          user_id: string
        }
        Update: {
          event_id?: string
          id?: string | null
          joined_at?: string
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_participants_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "scheduled_events"
            referencedColumns: ["id"]
          },
        ]
      }
      forum_post_tags: {
        Row: {
          tag_id: string
          thread_id: string
        }
        Insert: {
          tag_id: string
          thread_id: string
        }
        Update: {
          tag_id?: string
          thread_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "forum_post_tags_tag_id_fkey"
            columns: ["tag_id"]
            isOneToOne: false
            referencedRelation: "forum_tags"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "forum_post_tags_thread_id_fkey"
            columns: ["thread_id"]
            isOneToOne: false
            referencedRelation: "threads"
            referencedColumns: ["id"]
          },
        ]
      }
      forum_tags: {
        Row: {
          channel_id: string
          created_at: string | null
          emoji: string | null
          id: string
          moderated: boolean | null
          name: string
          position: number | null
        }
        Insert: {
          channel_id: string
          created_at?: string | null
          emoji?: string | null
          id?: string
          moderated?: boolean | null
          name: string
          position?: number | null
        }
        Update: {
          channel_id?: string
          created_at?: string | null
          emoji?: string | null
          id?: string
          moderated?: boolean | null
          name?: string
          position?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "forum_tags_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
        ]
      }
      friend_requests: {
        Row: {
          created_at: string
          id: string
          message: string | null
          receiver_id: string
          responded_at: string | null
          sender_id: string
          status: string
        }
        Insert: {
          created_at?: string
          id?: string
          message?: string | null
          receiver_id: string
          responded_at?: string | null
          sender_id: string
          status?: string
        }
        Update: {
          created_at?: string
          id?: string
          message?: string | null
          receiver_id?: string
          responded_at?: string | null
          sender_id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "friend_requests_receiver_id_fkey"
            columns: ["receiver_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "friend_requests_receiver_id_fkey"
            columns: ["receiver_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "friend_requests_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "friend_requests_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      friends: {
        Row: {
          created_at: string | null
          friend_id: string
          id: string
          status: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          friend_id: string
          id?: string
          status: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          friend_id?: string
          id?: string
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "friends_friend_id_fkey"
            columns: ["friend_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "friends_friend_id_fkey"
            columns: ["friend_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "friends_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "friends_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      friendships: {
        Row: {
          created_at: string
          friend_id: string
          nickname: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          friend_id: string
          nickname?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          friend_id?: string
          nickname?: string | null
          user_id?: string
        }
        Relationships: []
      }
      group_dm_participants: {
        Row: {
          group_dm_id: string
          joined_at: string
          user_id: string
        }
        Insert: {
          group_dm_id: string
          joined_at?: string
          user_id: string
        }
        Update: {
          group_dm_id?: string
          joined_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_dm_participants_group_dm_id_fkey"
            columns: ["group_dm_id"]
            isOneToOne: false
            referencedRelation: "group_dms"
            referencedColumns: ["id"]
          },
        ]
      }
      group_dms: {
        Row: {
          created_at: string
          icon: string | null
          id: string
          is_active: boolean
          name: string | null
          owner_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          icon?: string | null
          id?: string
          is_active?: boolean
          name?: string | null
          owner_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          icon?: string | null
          id?: string
          is_active?: boolean
          name?: string | null
          owner_id?: string
          updated_at?: string
        }
        Relationships: []
      }
      interactions: {
        Row: {
          application_id: string
          channel_id: string | null
          created_at: string | null
          data: Json | null
          guild_id: string | null
          id: string
          responded: boolean | null
          token: string
          type: number
          user_id: string
          version: number | null
        }
        Insert: {
          application_id?: string
          channel_id?: string | null
          created_at?: string | null
          data?: Json | null
          guild_id?: string | null
          id?: string
          responded?: boolean | null
          token?: string
          type: number
          user_id: string
          version?: number | null
        }
        Update: {
          application_id?: string
          channel_id?: string | null
          created_at?: string | null
          data?: Json | null
          guild_id?: string | null
          id?: string
          responded?: boolean | null
          token?: string
          type?: number
          user_id?: string
          version?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "interactions_guild_id_fkey"
            columns: ["guild_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      invite_usage: {
        Row: {
          id: string
          invite_code: string
          used_at: string
          user_id: string
        }
        Insert: {
          id?: string
          invite_code: string
          used_at?: string
          user_id: string
        }
        Update: {
          id?: string
          invite_code?: string
          used_at?: string
          user_id?: string
        }
        Relationships: []
      }
      invites: {
        Row: {
          channel_id: string | null
          code: string
          created_at: string
          created_by: string
          expires_at: string | null
          id: string | null
          is_expired: boolean
          max_uses: number
          server_id: string
          uses: number
        }
        Insert: {
          channel_id?: string | null
          code: string
          created_at?: string
          created_by: string
          expires_at?: string | null
          id?: string | null
          is_expired?: boolean
          max_uses?: number
          server_id: string
          uses?: number
        }
        Update: {
          channel_id?: string | null
          code?: string
          created_at?: string
          created_by?: string
          expires_at?: string | null
          id?: string | null
          is_expired?: boolean
          max_uses?: number
          server_id?: string
          uses?: number
        }
        Relationships: [
          {
            foreignKeyName: "invites_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invites_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      level_role_rewards: {
        Row: {
          id: string
          level: number
          remove_previous: boolean | null
          role_id: string
          server_id: string
        }
        Insert: {
          id?: string
          level: number
          remove_previous?: boolean | null
          role_id: string
          server_id: string
        }
        Update: {
          id?: string
          level?: number
          remove_previous?: boolean | null
          role_id?: string
          server_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "level_role_rewards_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      level_settings: {
        Row: {
          cooldown_seconds: number | null
          created_at: string | null
          enabled: boolean | null
          level_up_channel_id: string | null
          level_up_message: string | null
          no_xp_channels: string[] | null
          server_id: string
          stack_roles: boolean | null
          updated_at: string | null
          xp_max: number | null
          xp_min: number | null
        }
        Insert: {
          cooldown_seconds?: number | null
          created_at?: string | null
          enabled?: boolean | null
          level_up_channel_id?: string | null
          level_up_message?: string | null
          no_xp_channels?: string[] | null
          server_id: string
          stack_roles?: boolean | null
          updated_at?: string | null
          xp_max?: number | null
          xp_min?: number | null
        }
        Update: {
          cooldown_seconds?: number | null
          created_at?: string | null
          enabled?: boolean | null
          level_up_channel_id?: string | null
          level_up_message?: string | null
          no_xp_channels?: string[] | null
          server_id?: string
          stack_roles?: boolean | null
          updated_at?: string | null
          xp_max?: number | null
          xp_min?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "level_settings_level_up_channel_id_fkey"
            columns: ["level_up_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "level_settings_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: true
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      member_roles: {
        Row: {
          assigned_at: string
          id: string
          role_id: string
          server_id: string
          user_id: string
        }
        Insert: {
          assigned_at?: string
          id?: string
          role_id: string
          server_id: string
          user_id: string
        }
        Update: {
          assigned_at?: string
          id?: string
          role_id?: string
          server_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "member_roles_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "member_roles_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      mentions: {
        Row: {
          created_at: string
          id: string
          is_read: boolean
          mention_type: string
          message_id: string
          target_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          is_read?: boolean
          mention_type: string
          message_id: string
          target_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          is_read?: boolean
          mention_type?: string
          message_id?: string
          target_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "mentions_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      message_edit_history: {
        Row: {
          edited_at: string
          id: string
          message_id: string
          previous_content: string
        }
        Insert: {
          edited_at?: string
          id?: string
          message_id: string
          previous_content: string
        }
        Update: {
          edited_at?: string
          id?: string
          message_id?: string
          previous_content?: string
        }
        Relationships: [
          {
            foreignKeyName: "message_edit_history_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      message_flags: {
        Row: {
          is_crossposted: boolean
          is_ephemeral: boolean
          is_failed: boolean
          is_loading: boolean
          is_urgent: boolean
          message_id: string
        }
        Insert: {
          is_crossposted?: boolean
          is_ephemeral?: boolean
          is_failed?: boolean
          is_loading?: boolean
          is_urgent?: boolean
          message_id: string
        }
        Update: {
          is_crossposted?: boolean
          is_ephemeral?: boolean
          is_failed?: boolean
          is_loading?: boolean
          is_urgent?: boolean
          message_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "message_flags_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: true
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      message_replies: {
        Row: {
          created_at: string
          message_id: string
          replied_to_id: string
        }
        Insert: {
          created_at?: string
          message_id: string
          replied_to_id: string
        }
        Update: {
          created_at?: string
          message_id?: string
          replied_to_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "message_replies_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: true
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "message_replies_replied_to_id_fkey"
            columns: ["replied_to_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      messages: {
        Row: {
          attachments: Json | null
          author_id: string | null
          channel_id: string
          content: string
          content_tsv: unknown
          created_at: string | null
          edited: boolean
          edited_at: string | null
          embeds: Json | null
          id: string
          pinned: boolean | null
          reply_to_id: string | null
          thread_id: string | null
          type: string | null
          updated_at: string | null
        }
        Insert: {
          attachments?: Json | null
          author_id?: string | null
          channel_id: string
          content: string
          content_tsv?: unknown
          created_at?: string | null
          edited?: boolean
          edited_at?: string | null
          embeds?: Json | null
          id?: string
          pinned?: boolean | null
          reply_to_id?: string | null
          thread_id?: string | null
          type?: string | null
          updated_at?: string | null
        }
        Update: {
          attachments?: Json | null
          author_id?: string | null
          channel_id?: string
          content?: string
          content_tsv?: unknown
          created_at?: string | null
          edited?: boolean
          edited_at?: string | null
          embeds?: Json | null
          id?: string
          pinned?: boolean | null
          reply_to_id?: string | null
          thread_id?: string | null
          type?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "messages_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_reply_to_id_fkey"
            columns: ["reply_to_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_thread_id_fkey"
            columns: ["thread_id"]
            isOneToOne: false
            referencedRelation: "threads"
            referencedColumns: ["id"]
          },
        ]
      }
      mod_settings: {
        Row: {
          anti_spam_enabled: boolean | null
          anti_spam_interval: number | null
          anti_spam_threshold: number | null
          auto_role_id: string | null
          banned_words: string[] | null
          banned_words_action: string | null
          created_at: string | null
          enabled: boolean | null
          max_warning_action: string | null
          max_warnings: number | null
          mod_log_channel_id: string | null
          mute_role_id: string | null
          server_id: string
          updated_at: string | null
        }
        Insert: {
          anti_spam_enabled?: boolean | null
          anti_spam_interval?: number | null
          anti_spam_threshold?: number | null
          auto_role_id?: string | null
          banned_words?: string[] | null
          banned_words_action?: string | null
          created_at?: string | null
          enabled?: boolean | null
          max_warning_action?: string | null
          max_warnings?: number | null
          mod_log_channel_id?: string | null
          mute_role_id?: string | null
          server_id: string
          updated_at?: string | null
        }
        Update: {
          anti_spam_enabled?: boolean | null
          anti_spam_interval?: number | null
          anti_spam_threshold?: number | null
          auto_role_id?: string | null
          banned_words?: string[] | null
          banned_words_action?: string | null
          created_at?: string | null
          enabled?: boolean | null
          max_warning_action?: string | null
          max_warnings?: number | null
          mod_log_channel_id?: string | null
          mute_role_id?: string | null
          server_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "mod_settings_mod_log_channel_id_fkey"
            columns: ["mod_log_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mod_settings_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: true
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      music_queues: {
        Row: {
          created_at: string | null
          duration_seconds: number | null
          id: string
          position: number | null
          requested_by: string | null
          server_id: string
          title: string
          url: string
        }
        Insert: {
          created_at?: string | null
          duration_seconds?: number | null
          id?: string
          position?: number | null
          requested_by?: string | null
          server_id: string
          title: string
          url: string
        }
        Update: {
          created_at?: string | null
          duration_seconds?: number | null
          id?: string
          position?: number | null
          requested_by?: string | null
          server_id?: string
          title?: string
          url?: string
        }
        Relationships: [
          {
            foreignKeyName: "music_queues_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      music_settings: {
        Row: {
          created_at: string | null
          default_volume: number | null
          dj_role_id: string | null
          enabled: boolean | null
          now_playing_channel_id: string | null
          repeat_mode: string | null
          server_id: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          default_volume?: number | null
          dj_role_id?: string | null
          enabled?: boolean | null
          now_playing_channel_id?: string | null
          repeat_mode?: string | null
          server_id: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          default_volume?: number | null
          dj_role_id?: string | null
          enabled?: boolean | null
          now_playing_channel_id?: string | null
          repeat_mode?: string | null
          server_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "music_settings_now_playing_channel_id_fkey"
            columns: ["now_playing_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "music_settings_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: true
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          content: Json
          created_at: string | null
          id: string
          read: boolean | null
          type: string
          user_id: string
        }
        Insert: {
          content: Json
          created_at?: string | null
          id?: string
          read?: boolean | null
          type: string
          user_id: string
        }
        Update: {
          content?: Json
          created_at?: string | null
          id?: string
          read?: boolean | null
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      offline_message_queue: {
        Row: {
          attachments: Json | null
          channel_id: string
          client_id: string
          content: string
          created_at: string
          error_message: string | null
          id: string
          last_retry_at: string | null
          reply_to_id: string | null
          retry_count: number
          status: string
          user_id: string
        }
        Insert: {
          attachments?: Json | null
          channel_id: string
          client_id: string
          content: string
          created_at?: string
          error_message?: string | null
          id?: string
          last_retry_at?: string | null
          reply_to_id?: string | null
          retry_count?: number
          status?: string
          user_id: string
        }
        Update: {
          attachments?: Json | null
          channel_id?: string
          client_id?: string
          content?: string
          created_at?: string
          error_message?: string | null
          id?: string
          last_retry_at?: string | null
          reply_to_id?: string | null
          retry_count?: number
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "offline_message_queue_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
        ]
      }
      onboarding_completions: {
        Row: {
          completed_at: string
          selected_options: Json | null
          server_id: string
          user_id: string
        }
        Insert: {
          completed_at?: string
          selected_options?: Json | null
          server_id: string
          user_id: string
        }
        Update: {
          completed_at?: string
          selected_options?: Json | null
          server_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "onboarding_completions_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      permission_overwrites: {
        Row: {
          allow: number
          channel_id: string
          created_at: string
          deny: number
          id: string
          target_id: string
          target_type: string
          updated_at: string
        }
        Insert: {
          allow?: number
          channel_id: string
          created_at?: string
          deny?: number
          id?: string
          target_id: string
          target_type: string
          updated_at?: string
        }
        Update: {
          allow?: number
          channel_id?: string
          created_at?: string
          deny?: number
          id?: string
          target_id?: string
          target_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "permission_overwrites_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
        ]
      }
      pinned_messages: {
        Row: {
          channel_id: string
          id: string
          message_id: string
          pinned_at: string
          pinned_by: string
        }
        Insert: {
          channel_id: string
          id?: string
          message_id: string
          pinned_at?: string
          pinned_by: string
        }
        Update: {
          channel_id?: string
          id?: string
          message_id?: string
          pinned_at?: string
          pinned_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "pinned_messages_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pinned_messages_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      playlist_tracks: {
        Row: {
          added_by: string | null
          created_at: string | null
          duration_seconds: number | null
          id: string
          playlist_id: string
          position: number | null
          title: string
          url: string
        }
        Insert: {
          added_by?: string | null
          created_at?: string | null
          duration_seconds?: number | null
          id?: string
          playlist_id: string
          position?: number | null
          title: string
          url: string
        }
        Update: {
          added_by?: string | null
          created_at?: string | null
          duration_seconds?: number | null
          id?: string
          playlist_id?: string
          position?: number | null
          title?: string
          url?: string
        }
        Relationships: [
          {
            foreignKeyName: "playlist_tracks_playlist_id_fkey"
            columns: ["playlist_id"]
            isOneToOne: false
            referencedRelation: "playlists"
            referencedColumns: ["id"]
          },
        ]
      }
      playlists: {
        Row: {
          created_at: string | null
          creator_id: string | null
          id: string
          is_public: boolean | null
          name: string
          server_id: string
        }
        Insert: {
          created_at?: string | null
          creator_id?: string | null
          id?: string
          is_public?: boolean | null
          name: string
          server_id: string
        }
        Update: {
          created_at?: string | null
          creator_id?: string | null
          id?: string
          is_public?: boolean | null
          name?: string
          server_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "playlists_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      poll_options: {
        Row: {
          created_at: string
          id: string
          option_text: string
          poll_id: string
          position: number
        }
        Insert: {
          created_at?: string
          id?: string
          option_text: string
          poll_id: string
          position: number
        }
        Update: {
          created_at?: string
          id?: string
          option_text?: string
          poll_id?: string
          position?: number
        }
        Relationships: [
          {
            foreignKeyName: "poll_options_poll_id_fkey"
            columns: ["poll_id"]
            isOneToOne: false
            referencedRelation: "polls"
            referencedColumns: ["id"]
          },
        ]
      }
      poll_votes: {
        Row: {
          id: string
          option_id: string
          poll_id: string
          user_id: string
          voted_at: string
        }
        Insert: {
          id?: string
          option_id: string
          poll_id: string
          user_id: string
          voted_at?: string
        }
        Update: {
          id?: string
          option_id?: string
          poll_id?: string
          user_id?: string
          voted_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "poll_votes_option_id_fkey"
            columns: ["option_id"]
            isOneToOne: false
            referencedRelation: "poll_options"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "poll_votes_poll_id_fkey"
            columns: ["poll_id"]
            isOneToOne: false
            referencedRelation: "polls"
            referencedColumns: ["id"]
          },
        ]
      }
      polls: {
        Row: {
          allow_multiselect: boolean
          channel_id: string
          created_at: string
          creator_id: string
          duration_hours: number | null
          ended_at: string | null
          expires_at: string | null
          id: string
          message_id: string
          question: string
        }
        Insert: {
          allow_multiselect?: boolean
          channel_id: string
          created_at?: string
          creator_id: string
          duration_hours?: number | null
          ended_at?: string | null
          expires_at?: string | null
          id?: string
          message_id: string
          question: string
        }
        Update: {
          allow_multiselect?: boolean
          channel_id?: string
          created_at?: string
          creator_id?: string
          duration_hours?: number | null
          ended_at?: string | null
          expires_at?: string | null
          id?: string
          message_id?: string
          question?: string
        }
        Relationships: [
          {
            foreignKeyName: "polls_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "polls_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: true
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
        ]
      }
      premium_subscriptions: {
        Row: {
          cancel_at_period_end: boolean
          created_at: string
          current_period_end: string
          current_period_start: string
          status: string
          tier: string
          updated_at: string
          user_id: string
        }
        Insert: {
          cancel_at_period_end?: boolean
          created_at?: string
          current_period_end: string
          current_period_start: string
          status: string
          tier: string
          updated_at?: string
          user_id: string
        }
        Update: {
          cancel_at_period_end?: boolean
          created_at?: string
          current_period_end?: string
          current_period_start?: string
          status?: string
          tier?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      presence: {
        Row: {
          last_changed: string
          status: string
          user_id: string
        }
        Insert: {
          last_changed?: string
          status?: string
          user_id: string
        }
        Update: {
          last_changed?: string
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          accent_color: string | null
          avatar: string | null
          badges: Json | null
          banner: string | null
          bio: string | null
          created_at: string | null
          custom_status: string | null
          custom_status_emoji: string | null
          custom_status_expires_at: string | null
          discriminator: string
          display_name: string | null
          email: string
          flags: number | null
          id: string
          is_private: boolean | null
          last_seen: string | null
          pronouns: string | null
          status: string | null
          updated_at: string | null
          username: string
          verified: boolean | null
        }
        Insert: {
          accent_color?: string | null
          avatar?: string | null
          badges?: Json | null
          banner?: string | null
          bio?: string | null
          created_at?: string | null
          custom_status?: string | null
          custom_status_emoji?: string | null
          custom_status_expires_at?: string | null
          discriminator?: string
          display_name?: string | null
          email: string
          flags?: number | null
          id: string
          is_private?: boolean | null
          last_seen?: string | null
          pronouns?: string | null
          status?: string | null
          updated_at?: string | null
          username: string
          verified?: boolean | null
        }
        Update: {
          accent_color?: string | null
          avatar?: string | null
          badges?: Json | null
          banner?: string | null
          bio?: string | null
          created_at?: string | null
          custom_status?: string | null
          custom_status_emoji?: string | null
          custom_status_expires_at?: string | null
          discriminator?: string
          display_name?: string | null
          email?: string
          flags?: number | null
          id?: string
          is_private?: boolean | null
          last_seen?: string | null
          pronouns?: string | null
          status?: string | null
          updated_at?: string | null
          username?: string
          verified?: boolean | null
        }
        Relationships: []
      }
      push_notification_tokens: {
        Row: {
          created_at: string
          device_id: string | null
          id: string
          is_active: boolean
          platform: string
          token: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          device_id?: string | null
          id?: string
          is_active?: boolean
          platform: string
          token: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          device_id?: string | null
          id?: string
          is_active?: boolean
          platform?: string
          token?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      reactions: {
        Row: {
          created_at: string | null
          emoji: string
          id: string
          message_id: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          emoji: string
          id?: string
          message_id: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          emoji?: string
          id?: string
          message_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reactions_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reactions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reactions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      reports: {
        Row: {
          created_at: string
          description: string
          evidence: Json | null
          id: string
          report_type: string
          reporter_id: string
          reviewed_at: string | null
          reviewed_by: string | null
          server_id: string | null
          status: string
          target_id: string
          target_type: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description: string
          evidence?: Json | null
          id?: string
          report_type: string
          reporter_id: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          server_id?: string | null
          status?: string
          target_id: string
          target_type: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string
          evidence?: Json | null
          id?: string
          report_type?: string
          reporter_id?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          server_id?: string | null
          status?: string
          target_id?: string
          target_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "reports_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      roles: {
        Row: {
          color: string | null
          created_at: string | null
          hoist: boolean | null
          icon_url: string | null
          id: string
          mentionable: boolean | null
          name: string
          permissions: number | null
          position: number | null
          server_id: string
        }
        Insert: {
          color?: string | null
          created_at?: string | null
          hoist?: boolean | null
          icon_url?: string | null
          id?: string
          mentionable?: boolean | null
          name: string
          permissions?: number | null
          position?: number | null
          server_id: string
        }
        Update: {
          color?: string | null
          created_at?: string | null
          hoist?: boolean | null
          icon_url?: string | null
          id?: string
          mentionable?: boolean | null
          name?: string
          permissions?: number | null
          position?: number | null
          server_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "roles_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      scheduled_events: {
        Row: {
          channel_id: string | null
          created_at: string
          creator_id: string
          description: string | null
          end_time: string | null
          event_type: string
          id: string
          image_url: string | null
          interested_count: number | null
          location: string | null
          name: string
          recurrence_rule: string | null
          server_id: string
          start_time: string
          status: string
          updated_at: string
        }
        Insert: {
          channel_id?: string | null
          created_at?: string
          creator_id: string
          description?: string | null
          end_time?: string | null
          event_type: string
          id?: string
          image_url?: string | null
          interested_count?: number | null
          location?: string | null
          name: string
          recurrence_rule?: string | null
          server_id: string
          start_time: string
          status?: string
          updated_at?: string
        }
        Update: {
          channel_id?: string | null
          created_at?: string
          creator_id?: string
          description?: string | null
          end_time?: string | null
          event_type?: string
          id?: string
          image_url?: string | null
          interested_count?: number | null
          location?: string | null
          name?: string
          recurrence_rule?: string | null
          server_id?: string
          start_time?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "community_events_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "scheduled_events_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
        ]
      }
      screen_shares: {
        Row: {
          channel_id: string
          ended_at: string | null
          frame_rate: number
          id: string
          resolution: string
          session_id: string
          share_type: string
          started_at: string
          user_id: string
          viewer_count: number
        }
        Insert: {
          channel_id: string
          ended_at?: string | null
          frame_rate: number
          id?: string
          resolution: string
          session_id: string
          share_type: string
          started_at?: string
          user_id: string
          viewer_count?: number
        }
        Update: {
          channel_id?: string
          ended_at?: string | null
          frame_rate?: number
          id?: string
          resolution?: string
          session_id?: string
          share_type?: string
          started_at?: string
          user_id?: string
          viewer_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "screen_shares_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "screen_shares_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "voice_states"
            referencedColumns: ["session_id"]
          },
        ]
      }
      server_boost_status: {
        Row: {
          boost_count: number | null
          boost_level: number | null
          server_id: string
          updated_at: string | null
        }
        Insert: {
          boost_count?: number | null
          boost_level?: number | null
          server_id: string
          updated_at?: string | null
        }
        Update: {
          boost_count?: number | null
          boost_level?: number | null
          server_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "server_boost_status_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: true
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      server_boosts: {
        Row: {
          ended_at: string | null
          id: string
          is_active: boolean
          server_id: string
          started_at: string
          tier: number
          user_id: string
        }
        Insert: {
          ended_at?: string | null
          id?: string
          is_active?: boolean
          server_id: string
          started_at?: string
          tier?: number
          user_id: string
        }
        Update: {
          ended_at?: string | null
          id?: string
          is_active?: boolean
          server_id?: string
          started_at?: string
          tier?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "server_boosts_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      server_emojis: {
        Row: {
          allowed_roles: string[] | null
          created_at: string | null
          created_by: string | null
          id: string
          name: string
          object_name: string
          server_id: string
          url: string
          usage_count: number | null
        }
        Insert: {
          allowed_roles?: string[] | null
          created_at?: string | null
          created_by?: string | null
          id?: string
          name: string
          object_name: string
          server_id: string
          url: string
          usage_count?: number | null
        }
        Update: {
          allowed_roles?: string[] | null
          created_at?: string | null
          created_by?: string | null
          id?: string
          name?: string
          object_name?: string
          server_id?: string
          url?: string
          usage_count?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "server_emojis_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "server_emojis_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "server_emojis_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      server_members: {
        Row: {
          communication_disabled_until: string | null
          id: string
          joined_at: string | null
          nickname: string | null
          roles: string[] | null
          server_id: string
          timeout_until: string | null
          user_id: string
        }
        Insert: {
          communication_disabled_until?: string | null
          id?: string
          joined_at?: string | null
          nickname?: string | null
          roles?: string[] | null
          server_id: string
          timeout_until?: string | null
          user_id: string
        }
        Update: {
          communication_disabled_until?: string | null
          id?: string
          joined_at?: string | null
          nickname?: string | null
          roles?: string[] | null
          server_id?: string
          timeout_until?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "server_members_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "server_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "server_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      server_notification_settings: {
        Row: {
          level: string | null
          mobile_push: boolean | null
          mute_until: string | null
          muted: boolean | null
          server_id: string
          suppress_everyone: boolean | null
          suppress_role_mentions: boolean | null
          user_id: string
        }
        Insert: {
          level?: string | null
          mobile_push?: boolean | null
          mute_until?: string | null
          muted?: boolean | null
          server_id: string
          suppress_everyone?: boolean | null
          suppress_role_mentions?: boolean | null
          user_id: string
        }
        Update: {
          level?: string | null
          mobile_push?: boolean | null
          mute_until?: string | null
          muted?: boolean | null
          server_id?: string
          suppress_everyone?: boolean | null
          suppress_role_mentions?: boolean | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "server_notification_settings_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "server_notification_settings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "server_notification_settings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      server_onboarding: {
        Row: {
          created_at: string
          default_channel_ids: string[] | null
          enabled: boolean
          prompts: Json | null
          require_rules_acceptance: boolean
          rules: string[] | null
          server_id: string
          updated_at: string
          welcome_description: string | null
          welcome_image_url: string | null
          welcome_title: string
        }
        Insert: {
          created_at?: string
          default_channel_ids?: string[] | null
          enabled?: boolean
          prompts?: Json | null
          require_rules_acceptance?: boolean
          rules?: string[] | null
          server_id: string
          updated_at?: string
          welcome_description?: string | null
          welcome_image_url?: string | null
          welcome_title?: string
        }
        Update: {
          created_at?: string
          default_channel_ids?: string[] | null
          enabled?: boolean
          prompts?: Json | null
          require_rules_acceptance?: boolean
          rules?: string[] | null
          server_id?: string
          updated_at?: string
          welcome_description?: string | null
          welcome_image_url?: string | null
          welcome_title?: string
        }
        Relationships: [
          {
            foreignKeyName: "server_onboarding_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: true
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      server_perks: {
        Row: {
          audio_quality_kbps: number
          custom_emojis_limit: number
          has_animated_icon: boolean
          has_server_banner: boolean
          server_id: string
          stickers_limit: number
          updated_at: string
          upload_limit_mb: number
          vanity_url_code: string | null
        }
        Insert: {
          audio_quality_kbps?: number
          custom_emojis_limit?: number
          has_animated_icon?: boolean
          has_server_banner?: boolean
          server_id: string
          stickers_limit?: number
          updated_at?: string
          upload_limit_mb?: number
          vanity_url_code?: string | null
        }
        Update: {
          audio_quality_kbps?: number
          custom_emojis_limit?: number
          has_animated_icon?: boolean
          has_server_banner?: boolean
          server_id?: string
          stickers_limit?: number
          updated_at?: string
          upload_limit_mb?: number
          vanity_url_code?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "server_perks_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: true
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      server_templates: {
        Row: {
          code: string
          created_at: string
          creator_id: string
          description: string | null
          id: string | null
          name: string
          serialized_data: Json
          source_server_id: string
          updated_at: string
          usage_count: number
        }
        Insert: {
          code: string
          created_at?: string
          creator_id: string
          description?: string | null
          id?: string | null
          name: string
          serialized_data: Json
          source_server_id: string
          updated_at?: string
          usage_count?: number
        }
        Update: {
          code?: string
          created_at?: string
          creator_id?: string
          description?: string | null
          id?: string | null
          name?: string
          serialized_data?: Json
          source_server_id?: string
          updated_at?: string
          usage_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "server_templates_source_server_id_fkey"
            columns: ["source_server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      servers: {
        Row: {
          banner: string | null
          banner_url: string | null
          boost_level: number
          created_at: string | null
          description: string | null
          explicit_content_filter: string | null
          features: string[] | null
          icon: string | null
          id: string
          name: string
          owner_id: string
          region: string | null
          total_boosts: number
          updated_at: string | null
          verification_level: string | null
        }
        Insert: {
          banner?: string | null
          banner_url?: string | null
          boost_level?: number
          created_at?: string | null
          description?: string | null
          explicit_content_filter?: string | null
          features?: string[] | null
          icon?: string | null
          id?: string
          name: string
          owner_id: string
          region?: string | null
          total_boosts?: number
          updated_at?: string | null
          verification_level?: string | null
        }
        Update: {
          banner?: string | null
          banner_url?: string | null
          boost_level?: number
          created_at?: string | null
          description?: string | null
          explicit_content_filter?: string | null
          features?: string[] | null
          icon?: string | null
          id?: string
          name?: string
          owner_id?: string
          region?: string | null
          total_boosts?: number
          updated_at?: string | null
          verification_level?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "servers_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "servers_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      sessions: {
        Row: {
          created_at: string
          device_info: string | null
          expires_at: string
          id: string
          ip_address: string | null
          is_active: boolean
          last_activity: string
          refresh_token: string
          updated_at: string
          user_agent: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          device_info?: string | null
          expires_at: string
          id?: string
          ip_address?: string | null
          is_active?: boolean
          last_activity?: string
          refresh_token: string
          updated_at?: string
          user_agent?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          device_info?: string | null
          expires_at?: string
          id?: string
          ip_address?: string | null
          is_active?: boolean
          last_activity?: string
          refresh_token?: string
          updated_at?: string
          user_agent?: string | null
          user_id?: string
        }
        Relationships: []
      }
      slowmode_state: {
        Row: {
          channel_id: string
          last_message_at: string
          user_id: string
        }
        Insert: {
          channel_id: string
          last_message_at?: string
          user_id: string
        }
        Update: {
          channel_id?: string
          last_message_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "slowmode_state_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "slowmode_state_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "slowmode_state_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      song_history: {
        Row: {
          id: string
          played_at: string | null
          played_by: string | null
          server_id: string
          title: string
          url: string
        }
        Insert: {
          id?: string
          played_at?: string | null
          played_by?: string | null
          server_id: string
          title: string
          url: string
        }
        Update: {
          id?: string
          played_at?: string | null
          played_by?: string | null
          server_id?: string
          title?: string
          url?: string
        }
        Relationships: [
          {
            foreignKeyName: "song_history_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      soundboard_favorites: {
        Row: {
          created_at: string | null
          id: string
          sound_id: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          sound_id: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          sound_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "soundboard_favorites_sound_id_fkey"
            columns: ["sound_id"]
            isOneToOne: false
            referencedRelation: "soundboard_sounds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "soundboard_favorites_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "soundboard_favorites_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      soundboard_sounds: {
        Row: {
          created_at: string | null
          duration: number | null
          emoji: string | null
          id: string
          name: string
          play_count: number | null
          server_id: string
          sound_url: string
          updated_at: string | null
          uploaded_by: string
        }
        Insert: {
          created_at?: string | null
          duration?: number | null
          emoji?: string | null
          id?: string
          name: string
          play_count?: number | null
          server_id: string
          sound_url: string
          updated_at?: string | null
          uploaded_by: string
        }
        Update: {
          created_at?: string | null
          duration?: number | null
          emoji?: string | null
          id?: string
          name?: string
          play_count?: number | null
          server_id?: string
          sound_url?: string
          updated_at?: string | null
          uploaded_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "soundboard_sounds_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "soundboard_sounds_uploaded_by_fkey"
            columns: ["uploaded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "soundboard_sounds_uploaded_by_fkey"
            columns: ["uploaded_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      starboard_entries: {
        Row: {
          attachments: Json | null
          author_id: string
          content: string | null
          created_at: string | null
          id: string
          original_channel_id: string
          original_message_id: string
          server_id: string
          star_count: number | null
          starboard_message_id: string | null
        }
        Insert: {
          attachments?: Json | null
          author_id: string
          content?: string | null
          created_at?: string | null
          id?: string
          original_channel_id: string
          original_message_id: string
          server_id: string
          star_count?: number | null
          starboard_message_id?: string | null
        }
        Update: {
          attachments?: Json | null
          author_id?: string
          content?: string | null
          created_at?: string | null
          id?: string
          original_channel_id?: string
          original_message_id?: string
          server_id?: string
          star_count?: number | null
          starboard_message_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "starboard_entries_original_channel_id_fkey"
            columns: ["original_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "starboard_entries_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      starboard_settings: {
        Row: {
          bot_messages: boolean | null
          created_at: string | null
          embed_color: string | null
          enabled: boolean | null
          ignored_channels: string[] | null
          nsfw_allowed: boolean | null
          self_star: boolean | null
          server_id: string
          star_emoji: string | null
          star_threshold: number | null
          starboard_channel_id: string | null
          updated_at: string | null
        }
        Insert: {
          bot_messages?: boolean | null
          created_at?: string | null
          embed_color?: string | null
          enabled?: boolean | null
          ignored_channels?: string[] | null
          nsfw_allowed?: boolean | null
          self_star?: boolean | null
          server_id: string
          star_emoji?: string | null
          star_threshold?: number | null
          starboard_channel_id?: string | null
          updated_at?: string | null
        }
        Update: {
          bot_messages?: boolean | null
          created_at?: string | null
          embed_color?: string | null
          enabled?: boolean | null
          ignored_channels?: string[] | null
          nsfw_allowed?: boolean | null
          self_star?: boolean | null
          server_id?: string
          star_emoji?: string | null
          star_threshold?: number | null
          starboard_channel_id?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "starboard_settings_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: true
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "starboard_settings_starboard_channel_id_fkey"
            columns: ["starboard_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
        ]
      }
      starboard_stars: {
        Row: {
          created_at: string | null
          entry_id: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          entry_id: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          entry_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "starboard_stars_entry_id_fkey"
            columns: ["entry_id"]
            isOneToOne: false
            referencedRelation: "starboard_entries"
            referencedColumns: ["id"]
          },
        ]
      }
      stickers: {
        Row: {
          created_at: string
          creator_id: string
          description: string | null
          id: string
          image_url: string
          name: string
          server_id: string
          tags: string[] | null
          updated_at: string
          usage_count: number
        }
        Insert: {
          created_at?: string
          creator_id: string
          description?: string | null
          id?: string
          image_url: string
          name: string
          server_id: string
          tags?: string[] | null
          updated_at?: string
          usage_count?: number
        }
        Update: {
          created_at?: string
          creator_id?: string
          description?: string | null
          id?: string
          image_url?: string
          name?: string
          server_id?: string
          tags?: string[] | null
          updated_at?: string
          usage_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "stickers_creator_id_fkey"
            columns: ["creator_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stickers_creator_id_fkey"
            columns: ["creator_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stickers_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      stream_viewers: {
        Row: {
          id: string
          joined_at: string | null
          stream_id: string
          user_id: string
        }
        Insert: {
          id?: string
          joined_at?: string | null
          stream_id: string
          user_id: string
        }
        Update: {
          id?: string
          joined_at?: string | null
          stream_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stream_viewers_stream_id_fkey"
            columns: ["stream_id"]
            isOneToOne: false
            referencedRelation: "streams"
            referencedColumns: ["id"]
          },
        ]
      }
      streams: {
        Row: {
          channel_id: string
          ended_at: string | null
          id: string
          max_viewers: number | null
          server_id: string
          started_at: string | null
          status: string
          title: string | null
          user_id: string
          viewer_count: number | null
        }
        Insert: {
          channel_id: string
          ended_at?: string | null
          id?: string
          max_viewers?: number | null
          server_id: string
          started_at?: string | null
          status?: string
          title?: string | null
          user_id: string
          viewer_count?: number | null
        }
        Update: {
          channel_id?: string
          ended_at?: string | null
          id?: string
          max_viewers?: number | null
          server_id?: string
          started_at?: string | null
          status?: string
          title?: string | null
          user_id?: string
          viewer_count?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "streams_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "streams_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      subscriptions: {
        Row: {
          cancel_at_period_end: boolean | null
          created_at: string | null
          current_period_end: string
          current_period_start: string
          id: string
          plan: string
          revenuecat_id: string | null
          status: string
          store: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          cancel_at_period_end?: boolean | null
          created_at?: string | null
          current_period_end?: string
          current_period_start?: string
          id?: string
          plan: string
          revenuecat_id?: string | null
          status?: string
          store?: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          cancel_at_period_end?: boolean | null
          created_at?: string | null
          current_period_end?: string
          current_period_start?: string
          id?: string
          plan?: string
          revenuecat_id?: string | null
          status?: string
          store?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      temp_punishments: {
        Row: {
          active: boolean | null
          created_at: string | null
          expires_at: string
          id: string
          moderator_id: string | null
          reason: string | null
          server_id: string
          type: string
          user_id: string
        }
        Insert: {
          active?: boolean | null
          created_at?: string | null
          expires_at: string
          id?: string
          moderator_id?: string | null
          reason?: string | null
          server_id: string
          type: string
          user_id: string
        }
        Update: {
          active?: boolean | null
          created_at?: string | null
          expires_at?: string
          id?: string
          moderator_id?: string | null
          reason?: string | null
          server_id?: string
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "temp_punishments_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      thread_members: {
        Row: {
          joined_at: string
          last_read_message_id: string | null
          notification_settings: Json
          thread_id: string
          user_id: string
        }
        Insert: {
          joined_at?: string
          last_read_message_id?: string | null
          notification_settings?: Json
          thread_id: string
          user_id: string
        }
        Update: {
          joined_at?: string
          last_read_message_id?: string | null
          notification_settings?: Json
          thread_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thread_members_last_read_message_id_fkey"
            columns: ["last_read_message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "thread_members_thread_id_fkey"
            columns: ["thread_id"]
            isOneToOne: false
            referencedRelation: "threads"
            referencedColumns: ["id"]
          },
        ]
      }
      threads: {
        Row: {
          archive_at: string
          auto_archive_duration: string
          created_at: string
          creator_id: string
          id: string
          is_archived: boolean
          member_count: number
          message_count: number
          name: string
          parent_channel_id: string
          parent_message_id: string | null
          server_id: string
          type: string
          updated_at: string
        }
        Insert: {
          archive_at: string
          auto_archive_duration?: string
          created_at?: string
          creator_id: string
          id?: string
          is_archived?: boolean
          member_count?: number
          message_count?: number
          name: string
          parent_channel_id: string
          parent_message_id?: string | null
          server_id: string
          type: string
          updated_at?: string
        }
        Update: {
          archive_at?: string
          auto_archive_duration?: string
          created_at?: string
          creator_id?: string
          id?: string
          is_archived?: boolean
          member_count?: number
          message_count?: number
          name?: string
          parent_channel_id?: string
          parent_message_id?: string | null
          server_id?: string
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "threads_parent_channel_id_fkey"
            columns: ["parent_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "threads_parent_message_id_fkey"
            columns: ["parent_message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "threads_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      ticket_feedback: {
        Row: {
          comment: string | null
          created_at: string | null
          id: string
          rating: number
          ticket_id: string
          user_id: string
        }
        Insert: {
          comment?: string | null
          created_at?: string | null
          id?: string
          rating: number
          ticket_id: string
          user_id: string
        }
        Update: {
          comment?: string | null
          created_at?: string | null
          id?: string
          rating?: number
          ticket_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ticket_feedback_ticket_id_fkey"
            columns: ["ticket_id"]
            isOneToOne: false
            referencedRelation: "tickets"
            referencedColumns: ["id"]
          },
        ]
      }
      ticket_panels: {
        Row: {
          button_color: string | null
          button_label: string | null
          category: string | null
          channel_id: string
          created_at: string | null
          description: string | null
          id: string
          message_id: string | null
          server_id: string
          title: string | null
        }
        Insert: {
          button_color?: string | null
          button_label?: string | null
          category?: string | null
          channel_id: string
          created_at?: string | null
          description?: string | null
          id?: string
          message_id?: string | null
          server_id: string
          title?: string | null
        }
        Update: {
          button_color?: string | null
          button_label?: string | null
          category?: string | null
          channel_id?: string
          created_at?: string | null
          description?: string | null
          id?: string
          message_id?: string | null
          server_id?: string
          title?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ticket_panels_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ticket_panels_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      ticket_settings: {
        Row: {
          auto_close_hours: number | null
          close_message: string | null
          created_at: string | null
          enabled: boolean | null
          log_channel_id: string | null
          max_open_tickets: number | null
          server_id: string
          staff_role_ids: string[] | null
          ticket_category_id: string | null
          ticket_prefix: string | null
          updated_at: string | null
          welcome_message: string | null
        }
        Insert: {
          auto_close_hours?: number | null
          close_message?: string | null
          created_at?: string | null
          enabled?: boolean | null
          log_channel_id?: string | null
          max_open_tickets?: number | null
          server_id: string
          staff_role_ids?: string[] | null
          ticket_category_id?: string | null
          ticket_prefix?: string | null
          updated_at?: string | null
          welcome_message?: string | null
        }
        Update: {
          auto_close_hours?: number | null
          close_message?: string | null
          created_at?: string | null
          enabled?: boolean | null
          log_channel_id?: string | null
          max_open_tickets?: number | null
          server_id?: string
          staff_role_ids?: string[] | null
          ticket_category_id?: string | null
          ticket_prefix?: string | null
          updated_at?: string | null
          welcome_message?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ticket_settings_log_channel_id_fkey"
            columns: ["log_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ticket_settings_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: true
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ticket_settings_ticket_category_id_fkey"
            columns: ["ticket_category_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
        ]
      }
      tickets: {
        Row: {
          added_users: string[] | null
          category: string | null
          channel_id: string | null
          closed_at: string | null
          closed_by: string | null
          created_at: string | null
          creator_id: string
          first_response_at: string | null
          id: string
          last_activity_at: string | null
          message_count: number | null
          priority: string | null
          server_id: string
          status: string | null
          subject: string | null
          ticket_number: number
        }
        Insert: {
          added_users?: string[] | null
          category?: string | null
          channel_id?: string | null
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string | null
          creator_id: string
          first_response_at?: string | null
          id?: string
          last_activity_at?: string | null
          message_count?: number | null
          priority?: string | null
          server_id: string
          status?: string | null
          subject?: string | null
          ticket_number: number
        }
        Update: {
          added_users?: string[] | null
          category?: string | null
          channel_id?: string | null
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string | null
          creator_id?: string
          first_response_at?: string | null
          id?: string
          last_activity_at?: string | null
          message_count?: number | null
          priority?: string | null
          server_id?: string
          status?: string | null
          subject?: string | null
          ticket_number?: number
        }
        Relationships: [
          {
            foreignKeyName: "tickets_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      user_notes: {
        Row: {
          content: string
          owner_id: string
          target_id: string
          updated_at: string | null
        }
        Insert: {
          content?: string
          owner_id: string
          target_id: string
          updated_at?: string | null
        }
        Update: {
          content?: string
          owner_id?: string
          target_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_notes_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_notes_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_notes_target_id_fkey"
            columns: ["target_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_notes_target_id_fkey"
            columns: ["target_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_privacy_settings: {
        Row: {
          allow_dms_from_everyone: boolean
          allow_dms_from_server_members: boolean
          allow_friend_requests_from_everyone: boolean
          read_receipts: boolean
          show_current_activity: boolean
          show_online_status: boolean
          updated_at: string
          user_id: string
        }
        Insert: {
          allow_dms_from_everyone?: boolean
          allow_dms_from_server_members?: boolean
          allow_friend_requests_from_everyone?: boolean
          read_receipts?: boolean
          show_current_activity?: boolean
          show_online_status?: boolean
          updated_at?: string
          user_id: string
        }
        Update: {
          allow_dms_from_everyone?: boolean
          allow_dms_from_server_members?: boolean
          allow_friend_requests_from_everyone?: boolean
          read_receipts?: boolean
          show_current_activity?: boolean
          show_online_status?: boolean
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_privacy_settings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_privacy_settings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_settings: {
        Row: {
          created_at: string
          notification_settings: Json
          privacy_settings: Json
          theme: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          notification_settings?: Json
          privacy_settings?: Json
          theme?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          notification_settings?: Json
          privacy_settings?: Json
          theme?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_xp: {
        Row: {
          last_xp_at: string | null
          level: number | null
          message_count: number | null
          server_id: string
          user_id: string
          xp: number | null
        }
        Insert: {
          last_xp_at?: string | null
          level?: number | null
          message_count?: number | null
          server_id: string
          user_id: string
          xp?: number | null
        }
        Update: {
          last_xp_at?: string | null
          level?: number | null
          message_count?: number | null
          server_id?: string
          user_id?: string
          xp?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "user_xp_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      video_settings: {
        Row: {
          allow_camera: boolean | null
          allow_screen_share: boolean | null
          created_at: string | null
          id: string
          max_screen_share_fps: number | null
          max_screen_share_quality: string | null
          max_video_users: number | null
          server_id: string
          updated_at: string | null
        }
        Insert: {
          allow_camera?: boolean | null
          allow_screen_share?: boolean | null
          created_at?: string | null
          id?: string
          max_screen_share_fps?: number | null
          max_screen_share_quality?: string | null
          max_video_users?: number | null
          server_id: string
          updated_at?: string | null
        }
        Update: {
          allow_camera?: boolean | null
          allow_screen_share?: boolean | null
          created_at?: string | null
          id?: string
          max_screen_share_fps?: number | null
          max_screen_share_quality?: string | null
          max_video_users?: number | null
          server_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "video_settings_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: true
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      voice_connection_logs: {
        Row: {
          channel_id: string
          created_at: string
          event_type: string
          id: string
          latency_ms: number | null
          packet_loss_percent: number | null
          quality_score: number | null
          session_id: string
          user_id: string
        }
        Insert: {
          channel_id: string
          created_at?: string
          event_type: string
          id?: string
          latency_ms?: number | null
          packet_loss_percent?: number | null
          quality_score?: number | null
          session_id: string
          user_id: string
        }
        Update: {
          channel_id?: string
          created_at?: string
          event_type?: string
          id?: string
          latency_ms?: number | null
          packet_loss_percent?: number | null
          quality_score?: number | null
          session_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "voice_connection_logs_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
        ]
      }
      voice_states: {
        Row: {
          channel_id: string
          is_deafened: boolean
          is_muted: boolean
          is_self_deafened: boolean
          is_self_muted: boolean
          is_streaming: boolean
          is_video: boolean
          joined_at: string
          server_id: string
          session_id: string
          suppress: boolean
          updated_at: string
          user_id: string
        }
        Insert: {
          channel_id: string
          is_deafened?: boolean
          is_muted?: boolean
          is_self_deafened?: boolean
          is_self_muted?: boolean
          is_streaming?: boolean
          is_video?: boolean
          joined_at?: string
          server_id: string
          session_id: string
          suppress?: boolean
          updated_at?: string
          user_id: string
        }
        Update: {
          channel_id?: string
          is_deafened?: boolean
          is_muted?: boolean
          is_self_deafened?: boolean
          is_self_muted?: boolean
          is_streaming?: boolean
          is_video?: boolean
          joined_at?: string
          server_id?: string
          session_id?: string
          suppress?: boolean
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "voice_states_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "voice_states_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "voice_states_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "voice_states_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      warnings: {
        Row: {
          created_at: string
          id: string
          moderator_id: string | null
          reason: string
          server_id: string
          severity: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          moderator_id?: string | null
          reason: string
          server_id: string
          severity?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          moderator_id?: string | null
          reason?: string
          server_id?: string
          severity?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "warnings_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
      webhooks: {
        Row: {
          avatar_url: string | null
          channel_id: string
          created_at: string | null
          created_by: string
          id: string
          name: string
          token: string | null
        }
        Insert: {
          avatar_url?: string | null
          channel_id: string
          created_at?: string | null
          created_by: string
          id?: string
          name: string
          token?: string | null
        }
        Update: {
          avatar_url?: string | null
          channel_id?: string
          created_at?: string | null
          created_by?: string
          id?: string
          name?: string
          token?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "webhooks_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "webhooks_creator_id_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "webhooks_creator_id_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      welcome_settings: {
        Row: {
          auto_roles: string[] | null
          created_at: string | null
          dm_enabled: boolean | null
          dm_message: string | null
          enabled: boolean | null
          leave_channel_id: string | null
          leave_enabled: boolean | null
          leave_message: string | null
          server_id: string
          updated_at: string | null
          welcome_card_bg_color: string | null
          welcome_card_bg_url: string | null
          welcome_card_enabled: boolean | null
          welcome_card_text_color: string | null
          welcome_channel_id: string | null
          welcome_embed: boolean | null
          welcome_embed_color: string | null
          welcome_embed_title: string | null
          welcome_message: string | null
        }
        Insert: {
          auto_roles?: string[] | null
          created_at?: string | null
          dm_enabled?: boolean | null
          dm_message?: string | null
          enabled?: boolean | null
          leave_channel_id?: string | null
          leave_enabled?: boolean | null
          leave_message?: string | null
          server_id: string
          updated_at?: string | null
          welcome_card_bg_color?: string | null
          welcome_card_bg_url?: string | null
          welcome_card_enabled?: boolean | null
          welcome_card_text_color?: string | null
          welcome_channel_id?: string | null
          welcome_embed?: boolean | null
          welcome_embed_color?: string | null
          welcome_embed_title?: string | null
          welcome_message?: string | null
        }
        Update: {
          auto_roles?: string[] | null
          created_at?: string | null
          dm_enabled?: boolean | null
          dm_message?: string | null
          enabled?: boolean | null
          leave_channel_id?: string | null
          leave_enabled?: boolean | null
          leave_message?: string | null
          server_id?: string
          updated_at?: string | null
          welcome_card_bg_color?: string | null
          welcome_card_bg_url?: string | null
          welcome_card_enabled?: boolean | null
          welcome_card_text_color?: string | null
          welcome_channel_id?: string | null
          welcome_embed?: boolean | null
          welcome_embed_color?: string | null
          welcome_embed_title?: string | null
          welcome_message?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "welcome_settings_leave_channel_id_fkey"
            columns: ["leave_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "welcome_settings_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: true
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "welcome_settings_welcome_channel_id_fkey"
            columns: ["welcome_channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
        ]
      }
      xp_multipliers: {
        Row: {
          id: string
          multiplier: number | null
          server_id: string
          target_id: string
          target_type: string
        }
        Insert: {
          id?: string
          multiplier?: number | null
          server_id: string
          target_id: string
          target_type: string
        }
        Update: {
          id?: string
          multiplier?: number | null
          server_id?: string
          target_id?: string
          target_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "xp_multipliers_server_id_fkey"
            columns: ["server_id"]
            isOneToOne: false
            referencedRelation: "servers"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      users: {
        Row: {
          avatar_url: string | null
          banner_url: string | null
          bio: string | null
          created_at: string | null
          custom_status: string | null
          display_name: string | null
          email: string | null
          id: string | null
          status: string | null
          updated_at: string | null
          username: string | null
        }
        Insert: {
          avatar_url?: string | null
          banner_url?: string | null
          bio?: string | null
          created_at?: string | null
          custom_status?: string | null
          display_name?: string | null
          email?: string | null
          id?: string | null
          status?: string | null
          updated_at?: string | null
          username?: string | null
        }
        Update: {
          avatar_url?: string | null
          banner_url?: string | null
          bio?: string | null
          created_at?: string | null
          custom_status?: string | null
          display_name?: string | null
          email?: string | null
          id?: string | null
          status?: string | null
          updated_at?: string | null
          username?: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      check_slowmode_allowed: {
        Args: { p_channel_id: string; p_user_id: string }
        Returns: boolean
      }
      create_server_rpc: {
        Args: { p_description?: string; p_icon?: string; p_name: string }
        Returns: Json
      }
      dev_grant_nitro: {
        Args: { nitro_plan?: string; target_user_id: string }
        Returns: undefined
      }
      get_mutual_servers: {
        Args: { user_a: string; user_b: string }
        Returns: {
          icon: string
          id: string
          name: string
        }[]
      }
      get_permission_bit: { Args: { permission_name: string }; Returns: number }
      get_slowmode_remaining_seconds: {
        Args: { p_channel_id: string }
        Returns: number
      }
      get_unread_counts: {
        Args: { p_user_id: string }
        Returns: {
          channel_id: string
          mention_count: number
          unread_count: number
        }[]
      }
      has_permission: {
        Args: {
          permission_name: string
          target_channel_uuid: string
          target_user_uuid: string
        }
        Returns: boolean
      }
      increment_emoji_usage: {
        Args: { emoji_uuid: string }
        Returns: undefined
      }
      increment_sound_play_count: {
        Args: { sound_id: string }
        Returns: undefined
      }
      search_messages_with_highlights: {
        Args: {
          channel_ids: string[]
          result_limit?: number
          result_offset?: number
          search_query: string
          sort_order?: string
        }
        Returns: {
          author_id: string
          channel_id: string
          content: string
          created_at: string
          highlighted_content: string
          id: string
          rank: number
          server_id: string
        }[]
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const

