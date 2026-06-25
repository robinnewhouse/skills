# Data Agent Example Prompts

Five realistic example questions you can ask the data agent. These are intentionally phrased the way a real user might ask: clear enough to start, but sometimes vague enough that the data agent should ask clarifying questions before querying.

Each example names the *eventual* artifact the user wants, not the exact tables, columns, or SQL to use.

---

## 1. Revenue by Model (Business Health)

**Prompt:**

> Show me total revenue, inference spend, and gross margin for the last 30 days, broken down by inference model. Include the margin percentage for each model and export the result as a CSV.

**Expected artifact:** CSV export with revenue, cost, margin, and margin % per model.

---

## 2. AI Code Acceptance Rates (Product Quality)

**Prompt:**

> For the last month, which AI models produce code that users accept most often? Give me the acceptance rate (accepted lines / total suggested lines) per model, and also tell me which editing method (write to file, replace in file, or apply patch) has the highest acceptance. Plot the results as a bar chart.

**Expected artifact:** Bar chart showing acceptance rate by model and by editing method.

---

## 3. User Activation Funnel (Growth)

**Prompt:**

> I want to understand how users progress through the product. What percentage of users who start the app go on to initialize a workspace, start a task, have a conversation turn, and eventually complete a task? Show me the funnel with drop-off at each stage and highlight the biggest gap.

**Expected artifact:** Funnel report with user counts and conversion rates at each stage, identifying the largest drop-off.

---

## 4. Top Errors This Week (Reliability)

**Prompt:**

> What are the 10 most frequent errors users are running into this week? For each error, tell me how many distinct users are affected and whether certain models or providers are disproportionately impacted. Export as a CSV.

**Expected artifact:** CSV with top 10 errors, affected user counts, and associated models/providers.

---

## 5. Task Completion & Conversation Depth (Engagement)

**Prompt:**

> For tasks created in the last 14 days, what's the completion rate? Do completed tasks have more conversation turns on average than abandoned ones? Show me the distribution — maybe a histogram or summary stats — and tell me if the difference looks meaningful.

**Expected artifact:** Summary statistics comparing conversation turns for completed vs. abandoned tasks, with a note on whether the difference is significant.

