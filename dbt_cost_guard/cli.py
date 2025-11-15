"""
CLI interface for dbt-cost-guard
"""
import sys
import subprocess
import logging
import click
from pathlib import Path
from typing import Optional, List
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.prompt import Confirm

from dbt_cost_guard.estimator import CostEstimator
from dbt_cost_guard.config import load_config

console = Console()
logger = logging.getLogger(__name__)


def display_long_term_projections(total_cost: float):
    """Display long-term cost projections in a panel"""
    # Calculate projections
    daily = total_cost
    weekly = total_cost * 7
    monthly = total_cost * 30
    yearly = total_cost * 365
    
    # Different run frequency scenarios
    twice_daily = total_cost * 2 * 365
    hourly = total_cost * 24 * 365
    
    projection_table = Table(show_header=True, box=None, padding=(0, 2))
    projection_table.add_column("Frequency", style="cyan")
    projection_table.add_column("Cost", style="bold")
    projection_table.add_column("Annual", style="yellow")
    
    projection_table.add_row("Per Run", f"${total_cost:.2f}", "—")
    projection_table.add_row("Daily (1×)", f"${daily:.2f}", f"${yearly:.2f}/year")
    projection_table.add_row("Twice Daily", f"${daily * 2:.2f}/day", f"${twice_daily:.2f}/year")
    projection_table.add_row("Hourly (24×)", f"${hourly / 365:.2f}/day", f"${hourly:.2f}/year")
    projection_table.add_row("Weekly", f"${weekly:.2f}", f"${weekly * 52:.2f}/year")
    projection_table.add_row("Monthly", f"${monthly:.2f}", f"${monthly * 12:.2f}/year")
    
    console.print(Panel(
        projection_table,
        title="[bold cyan]💰 Long-Term Cost Projections[/bold cyan]",
        border_style="cyan"
    ))
    
    # Add savings comparison
    if total_cost > 10:
        savings_table = Table(show_header=False, box=None, padding=(0, 2))
        savings_table.add_column("Metric", style="cyan")
        savings_table.add_column("Value", style="bold green")
        
        # Calculate what you'd save with a smaller warehouse
        smaller_cost = total_cost / 8  # Assuming 3X-Large vs X-Small (8x difference)
        annual_savings = (total_cost - smaller_cost) * 365
        
        savings_table.add_row(
            "💡 Potential Annual Savings",
            f"${annual_savings:.2f}"
        )
        savings_table.add_row(
            "   (using X-Small instead)",
            f"Reduce daily cost: ${total_cost:.2f} → ${smaller_cost:.2f}"
        )
        
        console.print(Panel(
            savings_table,
            title="[bold green]💵 Cost Optimization Opportunity[/bold green]",
            border_style="green"
        ))


@click.group(invoke_without_command=True)
@click.option(
    "--project-dir",
    type=click.Path(exists=True),
    default=".",
    help="Which directory to look in for the dbt_project.yml file",
)
@click.option(
    "--profiles-dir",
    type=click.Path(exists=True),
    default=None,
    help="Which directory to look in for the profiles.yml file",
)
@click.option(
    "--cost-per-credit",
    type=float,
    default=None,
    help="Cost per Snowflake credit (overrides config)",
)
@click.option(
    "--threshold",
    type=float,
    default=None,
    help="Cost threshold in dollars (overrides config)",
)
@click.option(
    "--skip-cost-check",
    is_flag=True,
    default=False,
    help="Skip cost estimation and run dbt directly",
)
@click.option(
    "--verbose",
    "-v",
    is_flag=True,
    default=False,
    help="Enable verbose logging output",
)
@click.pass_context
def cli(
    ctx,
    project_dir: str,
    profiles_dir: Optional[str],
    cost_per_credit: Optional[float],
    threshold: Optional[float],
    skip_cost_check: bool,
    verbose: bool,
):
    """dbt Cost Guard - Estimate Snowflake query costs before running dbt"""
    
    # Configure logging based on verbose flag
    if verbose:
        logging.basicConfig(
            level=logging.DEBUG,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
    else:
        logging.basicConfig(
            level=logging.WARNING,
            format='%(levelname)s: %(message)s'
        )
    
    ctx.ensure_object(dict)
    ctx.obj["project_dir"] = Path(project_dir).resolve()
    ctx.obj["profiles_dir"] = Path(profiles_dir).resolve() if profiles_dir else None
    ctx.obj["cost_per_credit"] = cost_per_credit
    ctx.obj["threshold"] = threshold
    ctx.obj["skip_cost_check"] = skip_cost_check
    ctx.obj["verbose"] = verbose

    # If no subcommand is provided, show help
    if ctx.invoked_subcommand is None:
        click.echo(ctx.get_help())


@cli.command()
@click.option("--models", "-m", help="Specify models to run")
@click.option("--select", "-s", help="Specify models to select")
@click.option("--exclude", help="Specify models to exclude")
@click.option("--full-refresh", is_flag=True, help="Full refresh for incremental models")
@click.option("--fail-fast", is_flag=True, help="Stop execution on first failure")
@click.option("--threads", "-t", type=int, help="Number of threads to use")
@click.option(
    "--force",
    "-f",
    is_flag=True,
    help="Force execution without cost confirmation",
)
@click.argument("dbt_args", nargs=-1, type=click.UNPROCESSED)
@click.pass_context
def run(ctx, models, select, exclude, full_refresh, fail_fast, threads, force, dbt_args):
    """Run dbt with cost estimation"""
    project_dir = ctx.obj["project_dir"]
    profiles_dir = ctx.obj["profiles_dir"]
    skip_cost_check = ctx.obj["skip_cost_check"] or force

    # Build dbt command
    dbt_cmd = ["dbt", "run"]

    if models:
        dbt_cmd.extend(["--models", models])
    if select:
        dbt_cmd.extend(["--select", select])
    if exclude:
        dbt_cmd.extend(["--exclude", exclude])
    if full_refresh:
        dbt_cmd.append("--full-refresh")
    if fail_fast:
        dbt_cmd.append("--fail-fast")
    if threads:
        dbt_cmd.extend(["--threads", str(threads)])
    dbt_cmd.extend(["--project-dir", str(project_dir)])
    
    if profiles_dir:
        dbt_cmd.extend(["--profiles-dir", str(profiles_dir)])
    else:
        # Use project directory as profiles directory by default
        dbt_cmd.extend(["--profiles-dir", str(project_dir)])
    
    dbt_cmd.extend(dbt_args)

    if skip_cost_check:
        console.print("[yellow]⚠️  Skipping cost check...[/yellow]")
        _run_dbt_command(dbt_cmd)
        return

    # Load configuration
    try:
        config = load_config(
            project_dir,
            cost_per_credit=ctx.obj["cost_per_credit"],
            threshold=ctx.obj["threshold"],
        )
    except Exception as e:
        console.print(f"[red]Error loading configuration: {e}[/red]")
        sys.exit(1)

    # Initialize cost estimator
    try:
        estimator = CostEstimator(project_dir, profiles_dir, config)
    except Exception as e:
        console.print(f"[red]Error initializing cost estimator: {e}[/red]")
        console.print(
            "[yellow]Tip: Make sure your Snowflake connection is properly configured[/yellow]"
        )
        sys.exit(1)

    # Get models to run
    try:
        with console.status("[bold blue]Compiling dbt models..."):
            models_to_run = estimator.get_models_to_run(
                models=models or select, exclude=exclude
            )

        if not models_to_run:
            console.print("[yellow]No models to run[/yellow]")
            return

        console.print(f"[green]✓ Found {len(models_to_run)} models to run[/green]")
    except Exception as e:
        console.print(f"[red]Error compiling models: {e}[/red]")
        sys.exit(1)

    # Estimate costs
    console.print("\n[bold blue]🔍 Estimating query costs...[/bold blue]\n")

    try:
        with console.status("[bold blue]Analyzing queries..."):
            cost_estimates = estimator.estimate_run_costs(models_to_run)
    except Exception as e:
        console.print(f"[red]Error estimating costs: {e}[/red]")
        console.print("[yellow]Proceeding without cost estimation...[/yellow]")
        _run_dbt_command(dbt_cmd)
        return

    # Display cost breakdown
    total_cost = sum(est["estimated_cost"] for est in cost_estimates)
    _display_cost_breakdown(cost_estimates, total_cost, config)
    
    # Display long-term projections
    console.print()
    display_long_term_projections(total_cost)
    console.print()

    # Check thresholds
    per_model_threshold = config.get("warning_threshold_per_model", 5.0)
    total_threshold = config.get("warning_threshold_total_run", 5.0)

    high_cost_models = [
        est for est in cost_estimates if est["estimated_cost"] > per_model_threshold
    ]

    # Determine if we need confirmation
    needs_confirmation = False
    warnings = []

    if total_cost > total_threshold:
        needs_confirmation = True
        warnings.append(
            f"Total estimated cost (${total_cost:.2f}) exceeds threshold (${total_threshold:.2f})"
        )

    if high_cost_models:
        needs_confirmation = True
        warnings.append(
            f"{len(high_cost_models)} model(s) exceed per-model threshold (${per_model_threshold:.2f})"
        )

    if warnings:
        console.print()
        for warning in warnings:
            console.print(f"[bold red]⚠️  {warning}[/bold red]")

    if needs_confirmation:
        console.print()
        if not Confirm.ask(
            "[bold yellow]Do you want to proceed with this dbt run?[/bold yellow]",
            default=False,
        ):
            console.print("[red]❌ Run cancelled by user[/red]")
            sys.exit(0)
    else:
        console.print(
            f"\n[green]✓ Estimated cost (${total_cost:.2f}) is within threshold[/green]"
        )

    # Run dbt
    console.print("\n[bold blue]Running dbt...[/bold blue]\n")
    _run_dbt_command(dbt_cmd)


@cli.command()
@click.option(
    "--model",
    "-m",
    required=True,
    help="Model name to analyze",
)
@click.pass_context
def analyze(ctx, model):
    """Analyze cost breakdown for a specific model with detailed information"""
    import re
    from rich.panel import Panel
    
    project_dir = ctx.obj["project_dir"]
    profiles_dir = ctx.obj["profiles_dir"]

    # Load configuration
    try:
        config = load_config(
            project_dir,
            cost_per_credit=ctx.obj["cost_per_credit"],
            threshold=ctx.obj["threshold"],
        )
    except Exception as e:
        console.print(f"[red]Error loading configuration: {e}[/red]")
        sys.exit(1)

    # Initialize cost estimator
    try:
        estimator = CostEstimator(project_dir, profiles_dir, config)
    except Exception as e:
        console.print(f"[red]Error initializing cost estimator: {e}[/red]")
        sys.exit(1)

    # Get the specific model
    try:
        with console.status(f"[bold blue]Analyzing model: {model}..."):
            all_models = estimator.get_models_to_run()
            
            # Filter to exact match or substring match
            models_to_run = [m for m in all_models if m["name"] == model or model in m["name"]]

        if not models_to_run:
            console.print(f"[yellow]Model '{model}' not found[/yellow]")
            console.print(f"\n[cyan]Available models:[/cyan]")
            for m in all_models:
                console.print(f"  • {m['name']}")
            return

        if len(models_to_run) > 1:
            console.print(f"[yellow]Multiple models found matching '{model}', showing exact match or first[/yellow]")
            # Prefer exact match
            exact_match = [m for m in models_to_run if m["name"] == model]
            if exact_match:
                model_data = exact_match[0]
            else:
                model_data = models_to_run[0]
        else:
            model_data = models_to_run[0]
    except Exception as e:
        console.print(f"[red]Error finding model: {e}[/red]")
        sys.exit(1)

    # Estimate cost
    try:
        # Don't use status spinner so we can see debug output
        cost_estimate = estimator.estimate_model_cost(model_data)
    except Exception as e:
        console.print(f"[red]Error estimating cost: {e}[/red]")
        import traceback
        traceback.print_exc()
        sys.exit(1)

    # Display detailed analysis
    console.print(f"\n[bold cyan]📊 Cost Analysis: {model_data['name']}[/bold cyan]\n")

    # Basic info panel
    info_table = Table(show_header=False, box=None, padding=(0, 2))
    info_table.add_column("Property", style="cyan")
    info_table.add_column("Value")

    info_table.add_row("Model Name", model_data["name"])
    info_table.add_row("Database", model_data.get("database", "N/A"))
    info_table.add_row("Schema", model_data.get("schema", "N/A"))
    info_table.add_row("Alias", model_data.get("alias", model_data["name"]))

    console.print(Panel(info_table, title="[bold]Model Information[/bold]", border_style="cyan"))

    # Cost breakdown
    cost = cost_estimate["estimated_cost"]
    time_seconds = cost_estimate["estimated_time_seconds"]
    complexity = cost_estimate["complexity_score"]
    warehouse_size = cost_estimate.get("warehouse_size", "MEDIUM")
    credits_per_hour = cost_estimate.get("credits_per_hour", 4)

    # Format time
    if time_seconds >= 3600:
        time_str = f"{time_seconds / 3600:.1f} hours"
    elif time_seconds >= 60:
        time_str = f"{time_seconds / 60:.1f} minutes"
    else:
        time_str = f"{time_seconds:.1f} seconds"

    cost_table = Table(show_header=False, box=None, padding=(0, 2))
    cost_table.add_column("Metric", style="cyan")
    cost_table.add_column("Value")

    # Color code the cost
    if cost > config.get("warning_threshold_per_model", 5.0):
        cost_str = f"[red bold]${cost:.2f}[/red bold]"
    elif cost > config.get("warning_threshold_per_model", 5.0) * 0.7:
        cost_str = f"[yellow]${cost:.2f}[/yellow]"
    else:
        cost_str = f"[green]${cost:.2f}[/green]"

    # Complexity indicator
    if complexity > 80:
        complexity_str = f"[red]{complexity}[/red] (High)"
    elif complexity > 50:
        complexity_str = f"[yellow]{complexity}[/yellow] (Medium)"
    else:
        complexity_str = f"[green]{complexity}[/green] (Low)"

    cost_table.add_row("Estimated Cost", cost_str)
    cost_table.add_row("Estimated Time", time_str)
    cost_table.add_row("Complexity Score", complexity_str)
    cost_table.add_row("Warehouse Size", warehouse_size)
    cost_table.add_row("Credits/Hour", f"{credits_per_hour}")
    cost_table.add_row("Cost per Credit", f"${config.get('cost_per_credit', 3.0):.2f}")

    console.print(Panel(cost_table, title="[bold]Cost Breakdown[/bold]", border_style="cyan"))

    # SQL analysis
    sql = model_data.get("compiled_sql", "")
    if sql:
        sql_upper = sql.upper()
        
        # Count features
        join_count = len(re.findall(r"\bJOIN\b", sql_upper))
        window_count = len(re.findall(r"\bOVER\s*\(", sql_upper))
        cte_count = sql_upper.count("WITH ")
        subquery_count = sql_upper.count("SELECT") - 1
        has_group_by = "GROUP BY" in sql_upper
        has_distinct = "DISTINCT" in sql_upper
        has_order_by = "ORDER BY" in sql_upper

        analysis_table = Table(show_header=False, box=None, padding=(0, 2))
        analysis_table.add_column("Feature", style="cyan")
        analysis_table.add_column("Count", justify="right")

        analysis_table.add_row("SQL Length", f"{len(sql):,} characters")
        analysis_table.add_row("JOINs", str(join_count))
        analysis_table.add_row("Window Functions", str(window_count))
        analysis_table.add_row("CTEs (WITH)", str(cte_count))
        analysis_table.add_row("Subqueries", str(subquery_count))
        analysis_table.add_row("GROUP BY", "✓" if has_group_by else "✗")
        analysis_table.add_row("DISTINCT", "✓" if has_distinct else "✗")
        analysis_table.add_row("ORDER BY", "✓" if has_order_by else "✗")

        console.print(Panel(analysis_table, title="[bold]Query Analysis[/bold]", border_style="cyan"))

    # Dependencies
    depends_on = model_data.get("depends_on", {})
    nodes = depends_on.get("nodes", [])
    
    if nodes:
        console.print(f"\n[bold cyan]📦 Dependencies ({len(nodes)}):[/bold cyan]")
        for node_id in nodes:
            if node_id.startswith("source."):
                parts = node_id.split(".")
                if len(parts) >= 4:
                    console.print(f"  • [yellow]Source:[/yellow] {parts[2]}.{parts[3]}")
            elif node_id.startswith("model."):
                parts = node_id.split(".")
                if len(parts) >= 3:
                    console.print(f"  • [cyan]Model:[/cyan] {parts[2]}")

    # Recommendations
    console.print(f"\n[bold cyan]💡 Recommendations:[/bold cyan]")
    recommendations = []

    if cost > config.get("warning_threshold_per_model", 5.0):
        recommendations.append("[red]⚠️  High cost detected! Consider optimizing this model.[/red]")
    
    if window_count > 10:
        recommendations.append(f"[yellow]→ {window_count} window functions detected. Consider materializing intermediate results.[/yellow]")
    
    if join_count > 5:
        recommendations.append(f"[yellow]→ {join_count} JOINs detected. Verify all joins are necessary and indexed.[/yellow]")
    
    if complexity > 80:
        recommendations.append("[yellow]→ Very complex query. Consider breaking into multiple models.[/yellow]")
    
    if time_seconds > 3600:
        recommendations.append("[yellow]→ Estimated runtime > 1 hour. Consider incremental materialization.[/yellow]")
    
    if not recommendations:
        recommendations.append("[green]✓ No optimization issues detected.[/green]")
    
    for rec in recommendations:
        console.print(f"  {rec}")

    console.print()


@cli.command()
@click.option("--models", "-m", help="Specify models to estimate")
@click.option("--select", "-s", help="Specify models to select")
@click.option("--exclude", help="Specify models to exclude")
@click.pass_context
def estimate(ctx, models, select, exclude):
    """Estimate costs without running dbt"""
    project_dir = ctx.obj["project_dir"]
    profiles_dir = ctx.obj["profiles_dir"]

    # Load configuration
    try:
        config = load_config(
            project_dir,
            cost_per_credit=ctx.obj["cost_per_credit"],
            threshold=ctx.obj["threshold"],
        )
    except Exception as e:
        console.print(f"[red]Error loading configuration: {e}[/red]")
        sys.exit(1)

    # Initialize cost estimator
    try:
        estimator = CostEstimator(project_dir, profiles_dir, config)
    except Exception as e:
        console.print(f"[red]Error initializing cost estimator: {e}[/red]")
        sys.exit(1)

    # Get models to estimate
    try:
        with console.status("[bold blue]Compiling dbt models..."):
            models_to_run = estimator.get_models_to_run(
                models=models or select, exclude=exclude
            )

        if not models_to_run:
            console.print("[yellow]No models found[/yellow]")
            return

        console.print(f"[green]✓ Found {len(models_to_run)} models[/green]")
    except Exception as e:
        console.print(f"[red]Error compiling models: {e}[/red]")
        sys.exit(1)

    # Estimate costs
    console.print("\n[bold blue]🔍 Estimating query costs...[/bold blue]\n")

    try:
        with console.status("[bold blue]Analyzing queries..."):
            cost_estimates = estimator.estimate_run_costs(models_to_run)
    except Exception as e:
        console.print(f"[red]Error estimating costs: {e}[/red]")
        sys.exit(1)

    # Display results
    total_cost = sum(est["estimated_cost"] for est in cost_estimates)
    _display_cost_breakdown(cost_estimates, total_cost, config)
    
    # Display long-term projections
    console.print()
    display_long_term_projections(total_cost)
    console.print()


@cli.command()
@click.pass_context
def config(ctx):
    """Show current configuration"""
    project_dir = ctx.obj["project_dir"]

    try:
        cfg = load_config(project_dir)
        console.print(Panel("[bold]dbt Cost Guard Configuration[/bold]"))
        console.print(f"  Cost per credit: ${cfg.get('cost_per_credit', 3.0):.2f}")
        console.print(
            f"  Per-model threshold: ${cfg.get('warning_threshold_per_model', 5.0):.2f}"
        )
        console.print(
            f"  Total run threshold: ${cfg.get('warning_threshold_total_run', 5.0):.2f}"
        )
        console.print(f"  Project directory: {project_dir}")
    except Exception as e:
        console.print(f"[red]Error loading configuration: {e}[/red]")
        sys.exit(1)


def _display_cost_breakdown(
    cost_estimates: List[dict], total_cost: float, config: dict
) -> None:
    """Display cost breakdown table"""
    per_model_threshold = config.get("warning_threshold_per_model", 5.0)

    table = Table(title="Cost Estimate Breakdown", show_header=True, header_style="bold cyan")
    table.add_column("Model", style="cyan")
    table.add_column("Est. Cost", justify="right")
    table.add_column("Est. Time", justify="right")
    table.add_column("Complexity", justify="center")
    table.add_column("Status", justify="center")

    for est in cost_estimates:
        cost = est["estimated_cost"]
        time_str = f"{est['estimated_time_seconds']:.1f}s"

        # Color code based on threshold
        if cost > per_model_threshold:
            cost_str = f"[red bold]${cost:.2f}[/red bold]"
            status = "[red]⚠️[/red]"
        elif cost > per_model_threshold * 0.7:
            cost_str = f"[yellow]${cost:.2f}[/yellow]"
            status = "[yellow]○[/yellow]"
        else:
            cost_str = f"[green]${cost:.2f}[/green]"
            status = "[green]✓[/green]"

        # Complexity indicator
        complexity = est.get("complexity_score", 0)
        if complexity > 80:
            complexity_str = "[red]High[/red]"
        elif complexity > 50:
            complexity_str = "[yellow]Med[/yellow]"
        else:
            complexity_str = "[green]Low[/green]"

        table.add_row(
            est["model_name"],
            cost_str,
            time_str,
            complexity_str,
            status,
        )

    # Add total row
    table.add_section()
    table.add_row(
        "[bold]TOTAL[/bold]",
        f"[bold]${total_cost:.2f}[/bold]",
        "",
        "",
        "",
    )

    console.print(table)


def _run_dbt_command(cmd: List[str]) -> None:
    """Execute dbt command and exit with its return code"""
    try:
        result = subprocess.run(cmd)
        sys.exit(result.returncode)
    except FileNotFoundError:
        console.print("[red]Error: dbt command not found. Is dbt installed?[/red]")
        sys.exit(1)
    except Exception as e:
        console.print(f"[red]Error running dbt: {e}[/red]")
        sys.exit(1)


def main():
    """Main entry point"""
    cli(obj={})


if __name__ == "__main__":
    main()

