import os
import json
import requests
from xml.etree import ElementTree
from datetime import datetime, timezone


class Location:
    file: str
    line: int
    column: int
    info: str

    def __init__(self, xml_element):
        self.file = xml_element.get('file')
        self.line = int(xml_element.get('line'))
        self.column = int(xml_element.get('line'))
        self.info = xml_element.get('info')

    def __repr__(self):
        return f'{self.file}:{self.line}:{self.column}: {self.info}'


class CppcheckError:
    err_id: str
    severity: str
    msg: str
    verbose: str
    cwe: str
    err_hash: str
    location: Location

    def __init__(self, xml_element):
        self.err_id = xml_element.get('id')
        self.severity = xml_element.get('id')
        self.msg = xml_element.get('msg')
        self.verbose = xml_element.get('verbose')
        self.cwe = xml_element.get('cwe')
        self.err_hash = xml_element.get('hash')

    def __repr__(self):
        return f'{self.location} [{self.err_id}]'


class CheckRun:

    GITHUB_TOKEN = os.environ['GITHUB_TOKEN']
    GITHUB_EVENT_PATH = os.environ['GITHUB_EVENT_PATH']

    URI = 'https://api.github.com'
    # We need preview version to access check run API
    API_VERSION = 'antiope-preview'
    ACCEPT_HEADER_VALUE = f"application/vnd.github.{API_VERSION}+json"
    AUTH_HEADER_VALUE = f"token {GITHUB_TOKEN}"

    def __init__(self):
        # self.read_event_file()
        # self.read_meta_data()
        self.cppcheck_errors = []
        self.annotations = []

    def read_event_file(self):
        with open(self.GITHUB_EVENT_PATH) as event_file:
            self.event = json.loads(event_file.read())

    def read_meta_data(self):
        self.repo_full_name = self.event['repository']['full_name']
        pull_request = self.event.get('pull_request')
        if pull_request:
            self.head_sha = pull_request['head']['sha']
        else:
            check_suite = self.event['check_suite']
            self.head_sha = check_suite['pull_requests'][0]['base']['sha']

    def read_cppcheck_output(self):
        err_idx = -1
        # self.cppcheck_errors = []
        for event, node in ElementTree.iterparse('cppcheck_output.xml',
                                                 events=('start', 'end')):
            if node.tag == "error":
                if event == 'start':
                    self.cppcheck_errors.append(CppcheckError(node))
                    err_idx = len(self.cppcheck_errors) - 1
                else:
                    err_idx = -1
            elif node.tag == "location" and event == "start":
                try:
                    location = Location(node)
                    if err_idx != -1:
                        self.cppcheck_errors[err_idx].location = location
                except ValueError:
                    pass

            # Remove links to the sibling nodes
            node.clear()

    def create_annotations(self):
        for error in self.cppcheck_errors:
            loc = error.location
            self.annotations.append(dict(
                path=loc.file,
                start_line=loc.line,
                end_line=loc.line,
                annotation_level='notice',
                message=f'{loc.info} ({error.err_id})',
                start_column=loc.column,
                end_column=loc.column))

    def get_summary(self):
        summary = f"""
        Cppcheck Bug Hunting Summary:

        Total Warnings: {len(self.annotations)}
        """
        return summary

    def get_conclusion(self):
        if len(self.annotations) == 0:
            return 'success'
        return 'failure'

    def get_payload(self):
        summary = self.get_summary()
        conclusion = self.get_conclusion()

        payload = {
            'name': 'bug-hunting',
            'head_sha': self.head_sha,
            'status': 'completed',
            'conclusion': conclusion,
            'completed_at': datetime.now(timezone.utc).isoformat(),
            'output': {
                'title': 'Bug Hunting Result',
                'summary': summary,
                'text': 'Bug Hunting results',
                'annotations': self.annotations,
            },
        }
        return payload

    def create(self):
        self.create_annotations()
        payload = self.get_payload()
        print(payload)
        response = requests.post(
            f'{self.URI}/repos/{self.repo_full_name}/check-runs',
            headers={
                'Accept': self.ACCEPT_HEADER_VALUE,
                'Authorization': self.AUTH_HEADER_VALUE,
            },
            json=payload,
        )
        print(response.content)
        response.raise_for_status()


if __name__ == '__main__':
    check_run = CheckRun()
    check_run.read_cppcheck_output()
    print(check_run.cppcheck_errors)
    check_run.create()
