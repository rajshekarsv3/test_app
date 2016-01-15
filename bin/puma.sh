#! /bin/sh

PUMA_CONFIG_FILE=/apps/test_app/current/config/puma.rb
PUMA_PID_FILE=/apps/test_app/shared/tmp/pids/puma.pid
PUMA_SOCKET=/apps/test_app/shared/tmp/test_app.sock

# check if puma process is running
puma_is_running() {
  if [ -S $PUMA_SOCKET ] ; then
    if [ -e $PUMA_PID_FILE ] ; then
      echo "========"
      echo $PUMA_PID_FILE 
      if [ -d "/proc/"`cat $PUMA_PID_FILE` ] ; then
        return 0
      else
        echo "No puma process found"
      fi
    else
      echo "No puma pid file found"
    fi
  else
    echo "No puma socket found"
  fi

  return 1
}

case "$1" in
  start)
    echo "Starting puma..."
    rm -f $PUMA_SOCKET
    if [ -e $PUMA_CONFIG_FILE ] ; then
      RAILS_ENV="$2" bundle exec puma -d -C $PUMA_CONFIG_FILE
    else
      RAILS_ENV="$2" bundle exec puma
    fi

    echo "done"
    ;;

  stop)
    echo "Stopping puma..."
    kill -9 `cat $PUMA_PID_FILE`
    rm -f $PUMA_PID_FILE
    rm -f $PUMA_SOCKET

    echo "done"
    ;;

  restart)
    if puma_is_running ; then
      echo "Hot-restarting puma..."
      kill -9 `cat $PUMA_PID_FILE`

      echo "Doublechecking the process restart..."
      sleep 2
      if puma_is_running ; then
        echo "puma is still running"
        exit 0
      else
        echo "puma is killed"
      fi
    fi

    echo "Trying cold reboot"
    bin/puma.sh start "$2"
    ;;

  *)
    echo "Usage: script/puma.sh {start|stop|restart}" >&2
    ;;
esac

