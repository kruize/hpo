FROM registry.fedoraproject.org/f33/python3

LABEL name="Kruize HPO" \
      vendor="Red Hat" \
      run="docker run --rm -it -p 8085:8085 <image_name:tag>" \
      summary="Docker Image for HPO" \
      description="For more information on this image please see https://github.com/kruize/hpo/blob/main/README.md"

USER 0

# Copy ML hyperparameter tuning code and other required files
COPY src ./src/
COPY requirements.txt index.html experiment.html ./

# Documented here:
# https://docs.openshift.com/container-platform/4.6/openshift_images/create-images.html#images-create-guide-openshift_create-images
RUN chown -R 1001:0 ./
USER 1001

# Install the dependencies and required python packages
RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install --requirement requirements.txt

EXPOSE 8085 50051

# Run the application
CMD python3 -u src/service.py