#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

python_bin=${VIDUR_PYTHON:-python}
qps=${1:-8}
num_requests=${2:-32}
output_dir=${3:-simulator_output/rc2_two_replica}
export WANDB_MODE=disabled

common_args=(
    --seed 0
    --cluster_config_num_replicas 2
    --replica_config_device a100
    --replica_config_network_device a100_pairwise_nvlink
    --replica_config_model_name meta-llama/Meta-Llama-3-8B
    --replica_config_tensor_parallel_size 1
    --replica_config_num_pipeline_stages 1
    --replica_scheduler_config_type sarathi
    --sarathi_scheduler_config_batch_size_cap 32
    --sarathi_scheduler_config_chunk_size 512
    --request_generator_config_type synthetic
    --synthetic_request_generator_config_seed 0
    --synthetic_request_generator_config_num_requests "$num_requests"
    --length_generator_config_type fixed
    --fixed_request_length_generator_config_prefill_tokens 512
    --fixed_request_length_generator_config_decode_tokens 64
    --interval_generator_config_type poisson
    --poisson_request_interval_generator_config_seed 42
    --poisson_request_interval_generator_config_qps "$qps"
    --execution_time_predictor_config_type linear_regression
    --linear_regression_execution_time_predictor_config_polynomial_degree 2
    --linear_regression_execution_time_predictor_config_k_fold_cv_splits 2
    --linear_regression_execution_time_predictor_config_num_training_job_threads 2
    --linear_regression_execution_time_predictor_config_prediction_max_prefill_chunk_size 512
    --linear_regression_execution_time_predictor_config_prediction_max_batch_size 32
    --linear_regression_execution_time_predictor_config_prediction_max_tokens_per_request 1024
    --no-metrics_config_store_plots
    --no-metrics_config_write_json_trace
    --metrics_config_enable_chrome_trace
)

for policy in round_robin lor; do
    "$python_bin" -m vidur.main "${common_args[@]}" \
        --global_scheduler_config_type "$policy" \
        --metrics_config_output_dir "$output_dir/qps-${qps}_n-${num_requests}/$policy"
done
