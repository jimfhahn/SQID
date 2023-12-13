use std::{env::current_exe, process::Command};

use anyhow::{Context, Result};
use chrono::NaiveDate;

pub(super) fn do_dump_processing(dump_file: &str, dump_date: &NaiveDate) -> Result<()> {
    let sqid = current_exe().context("failed to get executable path")?;
    let sqid = sqid.to_str().expect("should be valid UTF-8");
    let dump_date = dump_date.format("%Y%m%d").to_string();
    let mut command = Command::new(sqid);
    command.args(["--only=process-dump", "--date", &dump_date, "--", dump_file]);

    log::info!("executing: {command:?}");

    let output = command
        .status()
        .context("failed to start the dump processing")?;

    if output.success() {
        log::info!("successfully processed dump");
    } else {
        log::error!("failed to start dump processing");
    }

    Ok(())
}
