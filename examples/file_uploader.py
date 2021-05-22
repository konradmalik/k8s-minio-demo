import urllib3
from pathlib import Path
from minio import Minio
from minio.error import S3Error

# needed to ignore self-signed certificate
http_client = urllib3.PoolManager(
                cert_reqs='CERT_NONE',
                assert_hostname=False,
            )

def upload(
    url: str, access_key: str, secret_key: str,
    bucket_name: str, object_name: str, local_file: Path,
):
    # Create a client with the MinIO server
    # its access key and secret key.
    client = Minio(
        url,
        access_key=access_key,
        secret_key=secret_key,
        http_client=http_client,
    )

    # Make a bucket if not exist.
    found = client.bucket_exists(bucket_name)
    if not found:
        client.make_bucket(bucket_name)
    else:
        print(f"Bucket '{bucket_name}' already exists")

    # Upload local_file as object name
    client.fput_object(
        bucket_name, object_name, local_file,
    )
    print(
        f"'{str(local_file)}' is successfully uploaded as "
        f"object '{object_name}' to bucket '{bucket_name}'."
    )


if __name__ == "__main__":
    url = "127.0.0.1:8443"
    #access_key = "minio"
    #secret_key = "minio123"
    access_key="YOURCONSOLEACCESS"
    secret_key="YOURCONSOLESECRET"
    bucket_name = "somebucket"
    object_name = "cities.csv"
    local_file = Path("./cities.csv")
    try:
        upload(
            url, access_key, secret_key,
            bucket_name, object_name, local_file,
        )
    except S3Error as exc:
        print("error occurred.", exc)
