# memcard

A new Flutter project.

## Account deletion

Signed-in users can choose **Account → Delete Account**. After the server confirms
deletion, the app clears the session, local cards, vocabulary cache, and study preferences.

The backend must implement `DELETE /api/auth/account` with Bearer authentication,
permanently delete the user and associated data, and revoke their tokens. Return
HTTP 200 or 204 only when deletion is complete; queued requests (202) are not
treated as completed deletion. Return a non-2xx response with a JSON `message` on
failure. Deploy this endpoint before releasing the flow.
