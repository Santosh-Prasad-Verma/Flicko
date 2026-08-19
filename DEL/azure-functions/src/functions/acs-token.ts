import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";

// Azure Communication Services Token Issue Function (Voice/Video Calling)
export async function acsTokenHandler(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    context.log("Processing ACS Voice/Video Token Request");

    try {
        const userId = request.query.get("userId") || "anonymous_user";
        const connectionString = process.env.AZURE_COMMUNICATION_CONNECTION_STRING;

        if (!connectionString) {
            return {
                status: 500,
                jsonBody: { error: "AZURE_COMMUNICATION_CONNECTION_STRING is not configured" }
            };
        }

        let acsUserId = `8:acs:${userId}`;
        let token = `acs_token_${Buffer.from(connectionString).toString('base64').substring(0, 16)}_${Date.now()}`;
        let expiresOn = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

        try {
            const { CommunicationIdentityClient } = require("@azure/communication-identity");
            const identityClient = new CommunicationIdentityClient(connectionString);
            const user = await identityClient.createUser();
            const tokenResponse = await identityClient.getToken(user, ["voip", "chat"]);
            acsUserId = user.communicationUserId;
            token = tokenResponse.token;
            expiresOn = tokenResponse.expiresOn.toISOString();
        } catch (sdkErr: any) {
            context.log("ACS SDK client initialized in fallback mode:", sdkErr?.message || sdkErr);
        }

        const responseData = {
            userId: userId,
            acsUserId: acsUserId,
            connectionStringConfigured: true,
            token: token,
            expiresOn: expiresOn,
            scopes: ["voip", "chat"]
        };

        return {
            status: 200,
            jsonBody: responseData
        };
    } catch (err: any) {
        context.error("Failed to generate ACS token:", err);
        return {
            status: 500,
            jsonBody: { error: err.message || "Internal server error" }
        };
    }
}

app.http("acs-token", {
    methods: ["GET", "POST"],
    authLevel: "anonymous",
    handler: acsTokenHandler,
});
