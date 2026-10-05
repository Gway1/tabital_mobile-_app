"""Adds a demo customer with the CLAUDE.md §5.3 plan to the LOCAL dev database, so the app has
something to show. Never run it against staging or production.

    cd tabital
    set DATABASE_URL=sqlite:///C:/Users/LENOVO/AppData/Local/Temp/tabital_local_dev.db
    .venv\\Scripts\\python.exe "..\\Tabital Mobile App\\dev\\seed_demo_customer.py"

Demo sign-in (local test account only):
    phone     0249990001
    password  DemoCustomer-2026

The plan: GHS 4,000 phone, Pay in 4, 40% down. Payment 1 (GHS 1,600) was paid on 1 Sep 2026,
payment 2 (GHS 800) was due on 1 Oct 2026 and is unpaid, so the daily job marks it overdue and
charges the 10% late fee. Payments 3 and 4 fall due on 1 Nov and 1 Dec 2026.
Running the script again does nothing if the demo customer already exists.
"""
import os
import sys
from datetime import date, datetime

if "sqlite" not in os.environ.get("DATABASE_URL", ""):
    sys.exit("Refusing to run: DATABASE_URL must point at the local SQLite dev database.")

sys.path.insert(0, os.getcwd())          # run from the tabital/ folder

from app import create_app                                   # noqa: E402
from app.extensions import db, guard                         # noqa: E402
from app.models.instalment import InstalmentPlan             # noqa: E402
from app.models.instalment_payment import InstalmentPayment  # noqa: E402
from app.models.user import User                             # noqa: E402
from app.services import ledger, servicing                   # noqa: E402

PHONE, PASSWORD = "0249990001", "DemoCustomer-2026"

app = create_app()
with app.app_context():
    if User.query.filter_by(phone=PHONE).first():
        sys.exit("The demo customer already exists. Nothing to do.")
    merchant = User.query.filter_by(role="merchant").first()
    if merchant is None:
        merchant = User(phone="0249990002", role="merchant", status="approved", business_name="Accra Phones (demo)",
                        password=guard.hash_password("DemoMerchant-2026"))
        db.session.add(merchant)
    customer = User(phone=PHONE, role="customer", status="approved", full_name="Ama Mensah",
                    email="ama.demo@example.test", monthly_salary=5000, password=guard.hash_password(PASSWORD))
    db.session.add(customer)
    db.session.flush()

    plan = InstalmentPlan(plan_id="PLN-DEMO-1", merchant_id=merchant.id, customer_id=customer.id,
                          plan_name="Samsung Galaxy A55", description="128 GB, black",
                          total_amount=4000, down_payment=1600, remaining_amount=2400, number_of_installments=4,
                          installment_amount=800, frequency="monthly", start_date=datetime(2026, 9, 1),
                          end_date=datetime(2026, 12, 1), status="active", payment_status="partial",
                          paid_installments=1, customer_name="Ama Mensah", customer_phone=PHONE)
    db.session.add(plan)
    db.session.flush()
    ledger.open_plan(plan, 4000, 400, 3600, fee_note="Merchant discount (MDR) 10.00% (demo)")

    dues = [date(2026, 9, 1), date(2026, 10, 1), date(2026, 11, 1), date(2026, 12, 1)]
    for n, (due, amount) in enumerate(zip(dues, [1600, 800, 800, 800]), start=1):
        row = InstalmentPayment(payment_id=f"PAY-DEMO-{n}", plan_id=plan.id, installment_number=n,
                                due_date=datetime(due.year, due.month, due.day), amount=amount,
                                paid_amount=amount if n == 1 else 0, status="paid" if n == 1 else "pending",
                                paid_date=datetime(2026, 9, 1) if n == 1 else None,
                                payment_reference="DEMO-DP-1" if n == 1 else None, late_fee=0, late_fee_paid=False)
        db.session.add(row)
        db.session.flush()
        if n == 1:
            ledger.payment_received(plan, row, amount, "DEMO-DP-1")
    db.session.commit()

    # The real daily job marks payment 2 overdue and charges its late fee
    summary = servicing.run_daily(send_reminders=False, run_autopay=False)
    print("Demo customer added. Daily job:", summary)
