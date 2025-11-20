docker compose up -d
This command downloads the latest PostgreSQL image, creates the `db` service, exposes port 5432, and starts the database container.

### Step 2: Implement a Data Synchronization Strategy

True **synchronization** (sync) means handling changes that happen both in your application (local) and directly in the database (remote). The best way to implement this is using a design pattern often called **Change Data Capture (CDC)** or **Polling**. 

[Image of Change Data Capture architecture]


Since you are using SwiftUI/SwiftData for the client, and assuming a backend service will handle the synchronization logic, here is the architectural approach for the backend service:

#### A. Architecture Overview

1.  **Client (SwiftData):** Your application uses SwiftData for its local data model.
2.  **Backend Service (e.g., in Python/Node.js/Go):** This service acts as the intermediary between the client and PostgreSQL. It manages the two-way sync.
3.  **Database (PostgreSQL):** The source of truth.

#### B. Implementation for Synchronization (Conceptual Logic)

Synchronization requires tracking two types of changes:

| Type of Sync | Description | PostgreSQL Mechanism |
| :--- | :--- | :--- |
| **Local to Remote (Push Changes)** | Your app modified/created a goal (e.g., `currentValue` increased), and needs to update PostgreSQL. | Standard SQL `INSERT`, `UPDATE`, or `DELETE` commands sent from the backend service based on client requests (e.g., REST API calls). |
| **Remote to Local (Pull Changes)** | Data was changed directly in PostgreSQL (e.g., an admin edited a goal) and needs to be pulled by your app. | **Timestamps (`updated_at`):** Query the database for records where `updated_at` is newer than the client's last sync time. |

---

### Step 3: Detailed Logic for Remote-to-Local Sync (Pull)

To efficiently get new data from PostgreSQL, you must rely on a timestamp column.

1.  **Database Setup (SQL):** Add an `updated_at` column to your PostgreSQL table and set up a trigger to automatically update it on every change.

    ```sql
    CREATE TABLE goals (
        id UUID PRIMARY KEY,
        name TEXT NOT NULL,
        target_value INTEGER NOT NULL,
        current_value INTEGER NOT NULL,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );

    -- Trigger function to update the updated_at column on change
    CREATE OR REPLACE FUNCTION set_updated_at()
    RETURNS TRIGGER AS $$
    BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    -- Attach the trigger to the table
    CREATE TRIGGER update_goal_updated_at
    BEFORE UPDATE ON goals
    FOR EACH ROW
    EXECUTE PROCEDURE set_updated_at();
    
2.  **Backend Service Logic:**

    * The client sends its `last_sync_timestamp` to the backend.
    * The backend runs a query like:
        ```sql
        SELECT * FROM goals WHERE updated_at > :last_sync_timestamp ORDER BY updated_at;
            * The backend sends the retrieved list of goals back to the client.

3.  **Client (SwiftData) Logic:**

    * Your SwiftData application stores the last successful sync time in `UserDefaults` or a small persistent model.
    * When the app receives the new data from the backend, it iterates through the incoming records:
        * If the record exists locally (match by `id`), update the local `Goal` object's properties.
        * If the record is new, insert a new local `Goal` object.
    * After applying all changes, save the *current* server timestamp as the new `last_sync_timestamp`.

### Step 4: Integrating with SwiftUI (Conceptual Client-Side)

In your `GoalListView.swift`, you would introduce a sync method triggered manually or periodically. Since the current SwiftData implementation is purely local, you would replace the local save logic with calls to your imaginary backend service.

```swift
// Example concept for a sync function in SwiftUI/SwiftData
private func syncData() {
    Task {
        let lastSync = UserDefaults.standard.object(forKey: "lastSyncTime") as? Date ?? Date.distantPast
        
        do {
            // 1. PUSH: Send local changes (requires tracking local pending changes, omitted for simplicity)
            // 2. PULL: Fetch remote changes since last sync time
            let remoteGoals = try await backendService.fetchGoals(since: lastSync) 
            
            // 3. APPLY: Merge remote changes into local SwiftData store
            await MainActor.run {
                applyRemoteChanges(remoteGoals)
                UserDefaults.standard.set(Date(), forKey: "lastSyncTime")
            }
            
        } catch {
            print("Sync failed: \(error)")
        }
    }
}

By using Docker to host PostgreSQL and implementing a timestamp-based synchronization layer on a backend service, you achieve reliable, bi-directional data flow between your local app and the source of truth database.