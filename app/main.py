# app/main.py
# Entry point for the FastAPI application.
# Run with:  python -m uvicorn app.main:app --reload

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.routes import auth_routes, item_routes, billing_routes, customer_routes, owner_routes

app = FastAPI(
    title="Supermarket Management System — API",
    description="Group 23 | IIT BHU CSE | DBMS Project\n\n"
                "Three roles: **Owner**, **Employee**, **Customer**.\n\n"
                "1. Call `POST /auth/login` to get a token.\n"
                "2. Click **Authorize** (top right) and paste the token.\n"
                "3. All other endpoints are now accessible based on your role.",
    version="1.0.0",
)

# Allow the frontend (any origin in dev) to talk to this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Restrict to the frontend URL in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register all route groups
app.include_router(auth_routes.router)
app.include_router(item_routes.router)
app.include_router(billing_routes.router)
app.include_router(customer_routes.router)
app.include_router(owner_routes.router)

# Serve the frontend statically
app.mount("/app", StaticFiles(directory="frontend", html=True), name="frontend")


@app.get("/", tags=["Health"])
def root():
    return {"message": "Supermarket API is running. Visit /docs for Swagger UI."}
