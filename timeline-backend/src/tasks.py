import os
import logging
from datetime import datetime, timezone, timedelta
import time
from typing import Optional, Dict, Any
from celery import Celery
from src.schema import TaskSchema, WorkflowSchema
from src.services.firebase_client import get_workflow_ref
from src.services.agents import analyze_query, search_with_exa, analyze_content
from src.utils import calculate_next_run

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

DEFAULT_LOOKBACK_DAYS = 7

CELERY_BROKER = os.getenv('CELERY_BROKER_URL', 'amqp://timeline:timeline@localhost:5672/timelinehost')
CELERY_BACKEND = os.getenv('CELERY_BACKEND_URL', 'redis://localhost:6379/0')

celery_app = Celery('tasks', broker=CELERY_BROKER, backend=CELERY_BACKEND)


def _determine_search_date_range(workflow: WorkflowSchema, now_utc: datetime) -> datetime:
    """
    Determine the start date for Exa search based on workflow state.

    Args:
        workflow: The workflow schema
        now_utc: Current UTC time

    Returns:
        datetime: Start date for search
    """
    if workflow.last_run_at_utc is not None:
        return workflow.last_run_at_utc

    # First run: use start_time or default to N days ago
    if workflow.start_time_utc < now_utc:
        return workflow.start_time_utc

    return now_utc - timedelta(days=DEFAULT_LOOKBACK_DAYS)


def _execute_agent_workflow(
    workflow: WorkflowSchema,
    start_date: datetime,
    end_date: datetime
) -> tuple[str, dict, dict, dict]:
    """
    Execute the 3-agent workflow and return results.

    Args:
        workflow: Workflow schema with query
        start_date: Start date for search
        end_date: End date for search

    Returns:
        tuple: (result, query_analysis, search_results, agent_times)

    Raises:
        Exception: If any agent fails
    """
    agent_times = {}

    # Agent 1: Analyze the query
    logger.info("Starting Agent 1: Query Analyzer")
    agent1_start = time.time()
    try:
        query_analysis = analyze_query(workflow.query)
        agent_times["agent1_query_analyzer"] = time.time() - agent1_start
        logger.info(f"Agent 1 completed in {agent_times['agent1_query_analyzer']:.2f}s")
    except Exception as e:
        logger.error(f"Agent 1 (Query Analyzer) failed: {e}")
        raise

    # Agent 2: Search with Exa
    logger.info("Starting Agent 2: Exa Search")
    agent2_start = time.time()
    try:
        search_results = search_with_exa(query_analysis, start_date, end_date)
        agent_times["agent2_exa_search"] = time.time() - agent2_start
        logger.info(f"Agent 2 completed in {agent_times['agent2_exa_search']:.2f}s - Found {search_results.get('num_results', 0)} results")
    except Exception as e:
        logger.error(f"Agent 2 (Exa Search) failed: {e}")
        raise

    # Agent 3: Analyze content and generate answer
    logger.info("Starting Agent 3: Content Analyzer")
    agent3_start = time.time()
    try:
        result = analyze_content(workflow.query, search_results)
        agent_times["agent3_content_analyzer"] = time.time() - agent3_start
        logger.info(f"Agent 3 completed in {agent_times['agent3_content_analyzer']:.2f}s")
    except Exception as e:
        logger.error(f"Agent 3 (Content Analyzer) failed: {e}")
        raise

    agent_times["total_execution_time"] = sum(agent_times.values())
    logger.info(f"All agents completed in {agent_times['total_execution_time']:.2f}s")

    return result, query_analysis, search_results, agent_times


@celery_app.task(bind=True)
def schedule_task(self, user_id: Optional[str] = None, workflow_id: Optional[str] = None) -> Dict[str, Any]:
    """
    Execute a scheduled workflow task with 3-agent processing.

    Args:
        self: Celery task context
        user_id: User ID who owns the workflow
        workflow_id: Workflow ID to execute

    Returns:
        dict: Execution result with status and IDs
    """
    try:
        # Validate inputs
        if not user_id or not workflow_id:
            logger.error("Missing required parameters: user_id or workflow_id")
            return {"error": "missing_parameters", "user_id": user_id, "workflow_id": workflow_id}

        # Fetch workflow from Firestore
        logger.info(f"Fetching workflow {workflow_id} for user {user_id}")
        workflow_ref = get_workflow_ref(user_id, workflow_id)
        snap = workflow_ref.get()

        if not snap.exists:
            logger.error(f"Workflow not found: {workflow_id}")
            return {"error": "workflow_not_found", "workflow_id": workflow_id}

        workflow_data = snap.to_dict()
        workflow = WorkflowSchema.model_validate(workflow_data)
        logger.info(f"Processing workflow query: {workflow.query}")

        # Determine search date range
        now_utc = datetime.now(timezone.utc)
        start_date = _determine_search_date_range(workflow, now_utc)
        logger.info(f"Search date range: {start_date.isoformat()} to {now_utc.isoformat()}")

        # Execute agent workflow
        try:
            result, query_analysis, search_results, agent_times = _execute_agent_workflow(
                workflow, start_date, now_utc
            )
        except Exception as e:
            # Update task status to FAILED
            current_task_id = getattr(self.request, "id", None)
            error_message = f"Agent workflow failed: {str(e)}"
            logger.error(error_message)

            if current_task_id and workflow.last_result is not None:
                # Update existing task to FAILED
                task_ref = workflow_ref.collection("tasks").document(current_task_id)
                task_ref.update({
                    "status": "FAILED",
                    "result": error_message,
                    "completed_at": now_utc
                })

            return {
                "error": "agent_execution_failed",
                "message": str(e),
                "workflow_id": workflow_id,
                "user_id": user_id
            }

        # Get current task ID
        current_task_id = getattr(self.request, "id", None)

        # Create or update task entry
        if workflow.last_result is None:
            # First run - create new task
            task = TaskSchema(
                task_id=current_task_id,
                workflow_id=workflow_id,
                owner_id=user_id,
                status="COMPLETED",
                result=result,
                query_analysis=query_analysis,
                search_results=search_results,
                agent_execution_times=agent_times,
                scheduled_run_at=now_utc,
                created_at=now_utc,
                completed_at=now_utc
            )
            workflow_ref.collection("tasks").document(task.task_id).set(task.model_dump())
            logger.info(f"Created first task: {task.task_id}")
        else:
            # Subsequent run - update existing task
            task_ref = workflow_ref.collection("tasks").document(current_task_id)
            task_ref.update({
                "status": "COMPLETED",
                "result": result,
                "query_analysis": query_analysis,
                "search_results": search_results,
                "agent_execution_times": agent_times,
                "completed_at": now_utc
            })
            logger.info(f"Updated task: {current_task_id}")

        # Calculate next run time
        next_run_time = calculate_next_run(
            workflow.start_time_utc,
            workflow.interval_seconds,
            from_time=now_utc
        )

        # Schedule next task if workflow is active
        next_task_id = None
        next_task_async = None

        if workflow.active:
            next_task_async = schedule_task.apply_async(
                (user_id, workflow_id),
                eta=next_run_time
            )
            next_task_id = next_task_async.id

            # Create scheduled task entry
            next_task = TaskSchema(
                task_id=next_task_id,
                workflow_id=workflow_id,
                owner_id=user_id,
                status="SCHEDULED",
                scheduled_run_at=next_run_time,
                created_at=now_utc
            )
            workflow_ref.collection("tasks").document(next_task.task_id).set(next_task.model_dump())
            logger.info(f"Scheduled next task: {next_task_id} at {next_run_time.isoformat()}")
        else:
            logger.info("Workflow is inactive, not scheduling next run")

        # Update workflow metadata
        workflow_ref.update({
            "last_result": result,
            "last_run_at_utc": now_utc,
            "next_run_at_utc": next_run_time if next_task_id else None,
            "next_run_id": next_task_id
        })

        logger.info(f"Workflow {workflow_id} completed successfully")
        return {
            "status": "ok",
            "workflow_id": workflow_id,
            "user_id": user_id,
            "completed_task_id": current_task_id,
            "next_task_id": next_task_id,
        }

    except ValueError as e:
        # Validation errors
        logger.error(f"Validation error in workflow {workflow_id}: {e}")
        return {"error": "validation_error", "message": str(e)}

    except Exception as e:
        # Catch-all for unexpected errors
        logger.exception(f"Unexpected error scheduling workflow {workflow_id}: {e}")
        return {"error": "internal_error", "message": str(e)}
