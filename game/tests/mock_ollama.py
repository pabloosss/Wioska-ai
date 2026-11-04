"""Run scene tests without downloading a model or touching the real user's saves."""
import http.server,json,os,pathlib,subprocess,tempfile,threading,time
class Handler(http.server.BaseHTTPRequestHandler):
    calls=0
    unloads=0
    def log_message(self,*args): pass
    def reply(self,data):
        encoded=json.dumps(data).encode()
        try:
            self.send_response(200)
            self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(encoded)))
            self.end_headers();self.wfile.write(encoded)
        except (BrokenPipeError,ConnectionResetError): pass
    def do_GET(self):
        self.reply({'models':[{'name':'qwen3:4b-instruct'},{'name':'qwen3.5:35b'}]})
    def do_POST(self):
        body=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        if self.path=='/api/generate':
            assert body['keep_alive']==0
            Handler.unloads+=1
            self.reply({'done':True});return
        assert self.path=='/api/chat'
        Handler.calls+=1
        call=Handler.calls
        data=json.loads(body['messages'][1]['content'])
        assert body['options']['num_ctx']==4096
        if call==1:
            time.sleep(.6)
            decisions=[{'name':p['name'],'action':'gather_food','reason':'Zapas jedzenia','next_actions':['eat']} for p in data['residents']]
            self.reply({'message':{'content':json.dumps({'decisions':decisions})}})
        elif call==2:
            self.reply({'message':{'content':'not JSON'}})
        else:
            time.sleep(1)
            self.reply({'message':{'content':'{}'}})

def main():
    server=http.server.ThreadingHTTPServer(('127.0.0.1',11434),Handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    try:
        with tempfile.TemporaryDirectory(prefix='wioska-test-') as folder:
            env=dict(os.environ,XDG_DATA_HOME=folder)
            project=pathlib.Path(__file__).resolve().parents[1]
            result=subprocess.run(['godot','--headless','--path',str(project),'--quit-after','1100','--script','res://tests/test_integration.gd'],env=env,capture_output=True,text=True,timeout=40)
            print(result.stdout);print(result.stderr)
            assert result.returncode==0 and 'PASS integration' in result.stdout and 'ERROR:' not in result.stderr
            assert Handler.calls==3 and Handler.unloads==1,(Handler.calls,Handler.unloads)
            print('PASS HTTP: 3 bounded requests and 1 model unload')
    finally: server.shutdown();server.server_close()
if __name__=='__main__':main()
