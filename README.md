# GoalTracker

GoalTracker is a cross-platform (macOS/iOS) application built with SwiftUI and SwiftData, designed to help users track their goals. It features a Python Flask backend that communicates with a PostgreSQL database, enabling bi-directional data synchronization between the client and the central database.

## Architecture Overview

The project follows a client-server architecture:

1.  **Client (SwiftUI/SwiftData):** A macOS (and potentially iOS) application built with SwiftUI for the UI and SwiftData for local data persistence. It interacts with the backend service to synchronize data.
2.  **Backend Service (Python/Flask):** A lightweight Flask application that acts as an intermediary between the client and the PostgreSQL database. It handles API requests for data synchronization (create, read, update, delete goals).
3.  **Database (PostgreSQL):** The central source of truth for all goal data, managed via Docker.

## Features

*   **Goal Management:** Create, view, update, and delete goals.
*   **Progress Tracking:** Increment goal progress and mark goals as complete.
*   **Bi-directional Synchronization:**
    *   **Local to Remote (Push):** Changes made in the SwiftData client (new goals, updates, deletions) are pushed to the PostgreSQL database via the Flask backend.
    *   **Remote to Local (Pull):** The client periodically fetches changes from the PostgreSQL database (based on `updated_at` timestamps) and merges them into its local SwiftData store.
*   **Dockerized Database:** Easy setup and management of the PostgreSQL database using Docker Compose.

## Setup Instructions

Follow these steps to get the GoalTracker project running on your local machine.

### Step 1: Set up the PostgreSQL Database with Docker Compose

Ensure you have Docker and Docker Compose installed on your system.

1.  **Start the database and backend containers:**
    Navigate to the root directory of the project in your terminal and run:
    ```bash
    docker compose up -d
    ```
    This command downloads the latest PostgreSQL image, creates the `db` service, exposes port 5432, and starts the database container in detached mode.
    
    The backend will start and attempt to connect to the `db` service (PostgreSQL). It will also automatically create the `goals` table and its `updated_at` trigger if they don't exist, with a retry mechanism to account for database startup time. You should see messages indicating that the server is running on `http://0.0.0.0:5001`.


### Step 2: Configure and Run the SwiftData macOS Client

The macOS application needs to be configured for network access and might require a cleanup of old data if you're upgrading.


1.  **Enable Network Access (App Sandbox):**
    *   In Xcode, select the **GoalTracker project** in the Project Navigator.
    *   Select the **"GoalTracker" target**.
    *   Go to the **"Signing & Capabilities"** tab.
    *   Click **"+ Capability"** and add **"App Sandbox"**.
    *   Under the "Network" section within "App Sandbox," ensure **"Outgoing Connections (Client)"** is checked. This allows your app to connect to the local backend server.

2.  **Run the application:**
    Build and run the GoalTracker app from Xcode.

## Data Synchronization Logic

The application implements a timestamp-based, bi-directional synchronization strategy:

### Client-Side (SwiftData)

*   **Local Data Model:** The client uses SwiftData for its local `Goal` objects. Each `Goal` has an `id` (UUID), `name`, `targetValue`, `currentValue`, `creationDate`, `isComplete`, and crucially, an `updatedAt` timestamp.
*   **`updatedAt` Tracking:** The `updatedAt` property of a `Goal` automatically updates whenever `name`, `targetValue`, `currentValue`, or `isComplete` changes via `didSet` observers.
*   **Push Changes (Local to Remote):**
    *   **Create:** When a new `Goal` is saved locally, the `NewGoalView` triggers an asynchronous call to `BackendService.shared.createGoal()`.
    *   **Update:** When a `Goal`'s progress is incremented (`GoalRowContent`, `GoalDetailView`) or edited (`EditGoalView`), an asynchronous call to `BackendService.shared.updateGoal()` is made.
    *   **Delete:** When a `Goal` is deleted locally, the `GoalListView` or `GoalDetailView` triggers an asynchronous call to `BackendService.shared.deleteGoal()`.
*   **Pull Changes (Remote to Local):**
    *   The `GoalListView` initiates a `syncData()` call `onAppear` and via a manual "Sync" button.
    *   It sends its `lastSyncTime` (stored in `UserDefaults`) to the backend.
    *   The `BackendService` fetches `GoalResponse` objects from the `/sync` endpoint that have an `updated_at` greater than `lastSyncTime`.
    *   The client's `applyRemoteChanges()` function iterates through these `remoteGoals`:
        *   If a remote goal `id` matches a local goal and the remote `updated_at` is newer, the local goal is updated.
        *   If no local goal matches the remote goal `id`, a new local `Goal` object is inserted.
    *   After applying all changes, the `lastSyncTime` in `UserDefaults` is updated to the server's timestamp received during the sync.

### Backend-Side (Python Flask)

*   **Database Schema Initialization:** On startup, `app.py`'s `_init_db()` function creates the `goals` table (if it doesn't exist) and an `updated_at` trigger that automatically updates the `updated_at` timestamp on any row modification.
*   **`/sync` (GET) Endpoint:**
    *   Receives `last_sync_timestamp` from the client.
    *   Queries the `goals` table for all records where `updated_at` is greater than the provided timestamp, ordered by `updated_at`.
    *   Returns a JSON list of `GoalResponse` objects and the current `server_timestamp`.
*   **`/goals` (POST) Endpoint:**
    *   Receives a JSON `GoalRequest` from the client.
    *   Inserts a new goal into the `goals` table. Handles `ValueError` for `Z` in ISO timestamps by converting `Z` to `+00:00`.
*   **`/goals/<uuid:goal_id>` (PUT) Endpoint:**
    *   Receives a JSON `GoalRequest` for updating an existing goal.
    *   Updates the specified goal in the `goals` table. Handles `ValueError` for `Z` in ISO timestamps.
*   **`/goals/<uuid:goal_id>` (DELETE) Endpoint:**
    *   Receives a goal `id`.
    *   Deletes the corresponding goal from the `goals` table.

## Troubleshooting

*   **"A server with the specified hostname could not be found." (Error Code: -1003)**
    *   Ensure your Python Flask backend is running (`python app.py` in the `backend` directory).
    *   Verify the `baseURL` in `BackendService.swift` matches the Flask server's address (`http://localhost:5001`).

*   **"Operation not permitted" (Error Code: 1) / Sandbox errors for networking**
    *   For macOS apps, ensure **"App Sandbox"** is enabled in `Signing & Capabilities` in Xcode, and **"Outgoing Connections (Client)"** is checked under the "Network" section.

*   **`ValueError: Invalid isoformat string: 'YYYY-MM-DDTHH:MM:SSZ'` in backend logs**
    *   This was addressed by adding `Z` to `+00:00` conversion in `app.py`'s `create_goal` and `update_goal` functions. Ensure your backend Docker image is rebuilt (`docker compose up --build -d`) after this change.

*   **`ERROR: relation "goals" does not exist` in `db-1` logs**
    *   Ensure the `_init_db()` function in `app.py` is called and has successfully created the tables.
    *   Ensure your backend Docker image is rebuilt (`docker compose up --build -d`) after the retry logic was added to `_init_db()`.
    *   Sometimes, manually connecting to the PostgreSQL container and verifying `\dt` can help: `docker exec -it <db-container-id> psql -U postgres`.

*   **`DELETE /goals/{uuid}` returns `404`**
    *   The goal ID sent by the client might not exist in the database. Verify successful creation first.
    *   Check backend logs for detailed messages from the `delete_goal` function to see the ID received and rows affected.
