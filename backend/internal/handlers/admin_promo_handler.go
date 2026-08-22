package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type AdminPromoHandler struct {
	db          *pgxpool.Pool
	logger      *zap.Logger
	acsService  services.AzureACSService
	mailService *services.MailService
}

func NewAdminPromoHandler(db *pgxpool.Pool, logger *zap.Logger, acsService services.AzureACSService, mailService *services.MailService) *AdminPromoHandler {
	return &AdminPromoHandler{
		db:          db,
		logger:      logger.Named("handler.admin_promo"),
		acsService:  acsService,
		mailService: mailService,
	}
}

type promoUser struct {
	ID        string    `json:"id"`
	Email     string    `json:"email"`
	Username  string    `json:"username"`
	CreatedAt time.Time `json:"created_at"`
}

type batchSendReq struct {
	Recipients []string `json:"recipients"`
	Template   string   `json:"template"`
	Subject    string   `json:"subject"`
	CustomBody string   `json:"custom_body,omitempty"`
}

func (h *AdminPromoHandler) isAdmin(r *http.Request, userID string) (bool, error) {
	var isAdmin bool
	err := h.db.QueryRow(r.Context(), `
		SELECT (
			(COALESCE(u.raw_app_meta_data->>'is_admin', 'false') = 'true') OR
			(COALESCE(u.raw_user_meta_data->>'is_admin', 'false') = 'true') OR
			(COALESCE(u.raw_user_meta_data->>'role', '') = 'admin') OR
			(COALESCE(p.flags, 0) & 1 > 0)
		)
		FROM public.users u
		LEFT JOIN public.profiles p ON p.id = u.id
		WHERE u.id = $1
	`, userID).Scan(&isAdmin)
	if err != nil {
		var flags int
		pErr := h.db.QueryRow(r.Context(), `SELECT COALESCE(flags, 0) FROM public.profiles WHERE id = $1`, userID).Scan(&flags)
		if pErr == nil {
			return (flags & 1) > 0, nil
		}
		return false, err
	}
	return isAdmin, nil
}

func (h *AdminPromoHandler) ListUsers(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	isAdmin, err := h.isAdmin(r, userID)
	if err != nil {
		h.logger.Error("failed to verify admin authorization", zap.String("userID", userID), zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to verify permissions")
		return
	}
	if !isAdmin {
		writeError(w, http.StatusForbidden, "forbidden: administrator privileges required")
		return
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT id, email, username, created_at
		FROM public.users
		WHERE email IS NOT NULL AND email != ''
		ORDER BY created_at DESC
		LIMIT 1000
	`)
	if err != nil {
		h.logger.Error("failed to list users for promo email", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to fetch users")
		return
	}
	defer rows.Close()

	users := make([]promoUser, 0)
	for rows.Next() {
		var u promoUser
		if err := rows.Scan(&u.ID, &u.Email, &u.Username, &u.CreatedAt); err == nil {
			users = append(users, u)
		}
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"users": users,
		"total": len(users),
	})
}

func (h *AdminPromoHandler) ListTemplates(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	isAdmin, err := h.isAdmin(r, userID)
	if err != nil {
		h.logger.Error("failed to verify admin authorization", zap.String("userID", userID), zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to verify permissions")
		return
	}
	if !isAdmin {
		writeError(w, http.StatusForbidden, "forbidden: administrator privileges required")
		return
	}

	templatesList := []map[string]string{
		{"id": "flicko_plus.html", "name": "Flicko+ Premium Promotion", "type": "promotional"},
		{"id": "upgrade.html", "name": "Feature Upgrade Announcement", "type": "promotional"},
		{"id": "welcome.html", "name": "Welcome New User", "type": "transactional"},
		{"id": "notification.html", "name": "General Digest / Activity Alert", "type": "promotional"},
		{"id": "security_alert.html", "name": "Security Alert Notice", "type": "transactional"},
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"templates": templatesList,
	})
}

func (h *AdminPromoHandler) SendBatch(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	isAdmin, err := h.isAdmin(r, userID)
	if err != nil {
		h.logger.Error("failed to verify admin authorization", zap.String("userID", userID), zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to verify permissions")
		return
	}
	if !isAdmin {
		writeError(w, http.StatusForbidden, "forbidden: administrator privileges required")
		return
	}

	var req batchSendReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || len(req.Recipients) == 0 {
		writeError(w, http.StatusBadRequest, "recipients array and template are required")
		return
	}

	if len(req.Recipients) > 100 {
		writeError(w, http.StatusBadRequest, "batch size cannot exceed 100 recipients per request")
		return
	}

	if req.Subject == "" {
		req.Subject = "Special Announcement from Flicko!"
	}

	sentCount := 0
	failedCount := 0

	for _, email := range req.Recipients {
		err := h.mailService.SendFlickoPlusConfirmation(email, "Flicko Member", "PROMO-CAMPAIGN", "₹0.00")
		if err != nil {
			h.logger.Error("failed to send promo email", zap.String("email", email), zap.Error(err))
			failedCount++
		} else {
			sentCount++
		}
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status":       "completed",
		"total":        len(req.Recipients),
		"sent_count":   sentCount,
		"failed_count": failedCount,
	})
}

func ServePromoAdminUI(w http.ResponseWriter, r *http.Request) {
	html := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Flicko Promotional Email Admin Dashboard | promo.flicko.dev</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Inter', sans-serif; }
        body { background-color: #0A0A0C; color: #E4E4E7; display: flex; height: 100vh; overflow: hidden; }
        .sidebar { width: 280px; background: #121215; border-right: 1px solid #27272A; padding: 24px; display: flex; flex-direction: column; }
        .logo { font-size: 20px; font-weight: 700; color: #52B788; margin-bottom: 32px; display: flex; align-items: center; gap: 8px; }
        .nav-item { padding: 12px 16px; border-radius: 8px; color: #A1A1AA; text-decoration: none; font-size: 14px; font-weight: 500; margin-bottom: 8px; background: #18181B; }
        .nav-item.active { background: #52B788; color: #000; font-weight: 600; }
        .main { flex: 1; padding: 32px; overflow-y: auto; display: flex; gap: 24px; }
        .panel { flex: 1; background: #121215; border: 1px solid #27272A; border-radius: 12px; padding: 24px; display: flex; flex-direction: column; }
        .panel-title { font-size: 18px; font-weight: 600; margin-bottom: 16px; color: #FFF; }
        .user-list { flex: 1; overflow-y: auto; border: 1px solid #27272A; border-radius: 8px; margin-bottom: 16px; max-height: 400px; }
        .user-item { padding: 12px 16px; border-bottom: 1px solid #18181B; display: flex; align-items: center; justify-content: space-between; font-size: 14px; }
        .btn { background: #52B788; color: #000; border: none; padding: 12px 20px; border-radius: 8px; font-weight: 600; cursor: pointer; font-size: 14px; }
        .btn:hover { opacity: 0.9; }
        .select-all-bar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; font-size: 14px; color: #A1A1AA; }
        .form-group { margin-bottom: 16px; }
        .form-group label { display: block; font-size: 14px; margin-bottom: 6px; color: #A1A1AA; }
        .form-control { width: 100%; padding: 10px 14px; background: #18181B; border: 1px solid #27272A; border-radius: 8px; color: #FFF; font-size: 14px; }
        .preview-box { background: #FFF; color: #000; padding: 20px; border-radius: 8px; height: 260px; overflow-y: auto; font-size: 14px; }
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="logo">⚡ Flicko Promo Admin</div>
        <a href="#" class="nav-item active">📧 Email Campaigns</a>
        <a href="#" class="nav-item">👥 User Directory</a>
        <a href="#" class="nav-item">⚙️ Mail Gateway Settings</a>
    </div>

    <div class="main">
        <div class="panel">
            <div class="panel-title">1. Select Target Users</div>
            <div class="select-all-bar">
                <span>Total Users: <strong id="user-count">Loading...</strong></span>
                <label><input type="checkbox" id="check-all" onclick="toggleSelectAll()"> Select All</label>
            </div>
            <div class="user-list" id="user-container">
                <div style="padding: 20px; text-align: center; color: #71717A;">Loading users from database...</div>
            </div>
        </div>

        <div class="panel">
            <div class="panel-title">2. Configure & Send Campaign</div>
            <div class="form-group">
                <label>Select Email Template</label>
                <select class="form-control" id="template-select">
                    <option value="flicko_plus.html">⚡ Flicko+ Premium Promotion</option>
                    <option value="upgrade.html">🚀 Feature Upgrade Announcement</option>
                    <option value="welcome.html">🎉 Welcome New User</option>
                    <option value="notification.html">📢 General Digest / Activity Alert</option>
                </select>
            </div>
            <div class="form-group">
                <label>Subject Line</label>
                <input type="text" class="form-control" id="subject-input" value="Unlock Special Perks with Flicko+ Today!">
            </div>
            <div class="form-group">
                <label>Live Template Preview</label>
                <div class="preview-box">
                    <h2>Flicko+ Exclusive Perks</h2>
                    <p>Upgrade today to get custom emojis, HD screen sharing, and priority voice channels!</p>
                </div>
            </div>
            <button class="btn" onclick="sendCampaign()">🚀 Dispatch Batch Campaign</button>
        </div>
    </div>

    <script>
        let loadedUsers = [];

        async function fetchUsers() {
            try {
                const res = await fetch('/api/v1/admin/promo/users');
                const data = await res.json();
                loadedUsers = data.users || [];
                document.getElementById('user-count').innerText = loadedUsers.length;
                
                const container = document.getElementById('user-container');
                container.innerHTML = loadedUsers.map(u => 
                    '<div class="user-item"><span><strong>' + u.username + '</strong> (' + u.email + ')</span><input type="checkbox" class="user-checkbox" value="' + u.email + '"></div>'
                ).join('');
            } catch (err) {
                document.getElementById('user-container').innerHTML = '<div style="padding:20px;color:#F87171;">Failed to load users.</div>';
            }
        }

        function toggleSelectAll() {
            const isChecked = document.getElementById('check-all').checked;
            document.querySelectorAll('.user-checkbox').forEach(cb => cb.checked = isChecked);
        }

        async function sendCampaign() {
            const selectedEmails = Array.from(document.querySelectorAll('.user-checkbox:checked')).map(cb => cb.value);
            if (selectedEmails.length === 0) {
                alert('Please select at least one recipient!');
                return;
            }

            const template = document.getElementById('template-select').value;
            const subject = document.getElementById('subject-input').value;

            if (!confirm('Are you sure you want to send this promotional campaign to ' + selectedEmails.length + ' users?')) return;

            try {
                const res = await fetch('/api/v1/admin/promo/send', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ recipients: selectedEmails, template: template, subject: subject })
                });
                const data = await res.json();
                alert('Campaign Sent Successfully! Total: ' + data.sent_count + ' delivered.');
            } catch (err) {
                alert('Failed to send campaign: ' + err);
            }
        }

        fetchUsers();
    </script>
</body>
</html>`

	w.Header().Set("Content-Type", "text/html")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(html))
}
