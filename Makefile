# Runs a job on Google Dataproc Hadoop Cluster.

.DEFAULT_GOAL     := all
SRC_DIR           := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
DATA_DIR          := $(SRC_DIR)/ncdc-data/data
CLOUD_REGION      := us-east1
CLOUD_PROJECT     := cmu-14-848
CLUSTER_NAME      := cmu-14-848-map-reduce-cluster
BUCKET_NAME       := cmu-14-848-map-reduce-hw-04
STREAM_MAPPER     := gs://$(BUCKET_NAME)/mapper.py
STREAM_REDUCER    := gs://$(BUCKET_NAME)/reducer.py
STREAM_JAR_PATH   := file:///usr/lib/hadoop/hadoop-streaming.jar
INPUT_FILES       := $(addprefix gs://$(BUCKET_NAME)/, 1901 1902)
BUCKET_OUT_DIR    := gs://$(BUCKET_NAME)/out
BUCKET_OUT_FILE   := $(BUCKET_OUT_DIR)/remote.txt
LOCAL_OUT_DIR     := $(SRC_DIR)/out
LOCAL_CMP_FILE    := $(SRC_DIR)/out/local.txt
REMOTE_CMP_FILE   := $(SRC_DIR)/out/remote.txt
OUT_FILE_COUNT    := 1

# Enable the Google Cloud Dataproc API; create a bucket for storing the mapper
# and reducer scripts, the data-set, provide a staging area for the cluster and
# storing results. This is necessary because Dataproc Hadoop Clusters use Cloud
# Storage as the backing storage service (which provides all the functionality
# of HDFS).
init:
	rm -rf $(LOCAL_OUT_DIR)
	mkdir -p $(LOCAL_OUT_DIR)
	gcloud services enable dataproc

	gsutil mb -c "standard" -p "$(CLOUD_PROJECT)" \
	-l "$(CLOUD_REGION)" "gs://$(BUCKET_NAME)"

# Upload the mapper and reducer scripts, along
# with the data-set to Google Cloud Storage.
upload:
	gsutil cp "$(SRC_DIR)/*.py" "gs://$(BUCKET_NAME)"
	gsutil cp "$(DATA_DIR)/*" "gs://$(BUCKET_NAME)"

# Create the Hadoop cluster. The configuration file
# is defined in "cluster.yaml".
cluster-up:
	gcloud dataproc clusters import "$(CLUSTER_NAME)" \
	--source "$(SRC_DIR)/cluster.yaml"                \
	--region "$(CLOUD_REGION)"

# Submit the MapReduce job.
submit-job:
	gcloud dataproc jobs submit hadoop --region "$(CLOUD_REGION)"    \
	--cluster=$(CLUSTER_NAME)  --jar="$(STREAM_JAR_PATH)" --         \
	-files "$(STREAM_MAPPER),$(STREAM_REDUCER)"                      \
	-mapper "mapper.py" -reducer "reducer.py" -combiner "reducer.py" \
	$(addprefix -input ,$(INPUT_FILES)) -output "$(BUCKET_OUT_DIR)"

# Download the computed results. Since Hadoop splits the results
# into "part-*" files, we use the "compose" functionality that is
# provided by Cloud Storage to merge the file. This is equivalent
# to running "hdfs dfs –getmerge part-*".
copy-results:
	gsutil compose "$(BUCKET_OUT_DIR)/part-*" "$(BUCKET_OUT_FILE)"
	gsutil cp "$(BUCKET_OUT_FILE)" "$(REMOTE_CMP_FILE)"
	sort "$(REMOTE_CMP_FILE)" -o "$(REMOTE_CMP_FILE)"

# Run the MapReduce locally, and store the output for comparison.
local-run:
	cat $(addprefix $(DATA_DIR)/, 1901 1902) | $(SRC_DIR)/mapper.py | \
	sort | "$(SRC_DIR)/reducer.py" > "$(LOCAL_CMP_FILE)"

# Compare the output generated locally with the one from Hadoop.
# They should match. Otherwise, "diff" will exit with a non-zero
# status.
compare:
	diff "$(LOCAL_CMP_FILE)" "$(REMOTE_CMP_FILE)"

# Cluster teardown.
cluster-down:
	gcloud dataproc clusters delete "$(CLUSTER_NAME)" \
	--region "$(CLOUD_REGION)"

# Clean-up all the Cloud Storage buckets.
delete:
	$(eval TMP_BUCKET_NAME := $(shell gcloud dataproc clusters  \
	describe "$(CLUSTER_NAME)" --region "$(CLOUD_REGION)"       \
	--format "value(config.tempBucket)"))

	gsutil -m rm -r "gs://$(BUCKET_NAME)"
	gsutil -m rm -r "gs://$(TMP_BUCKET_NAME)"

all: init upload cluster-up submit-job copy-results local-run compare

clean: delete cluster-down

.PHONY: init upload cluster-up submit-job copy-results local-run
		compare cluster-down all clean
