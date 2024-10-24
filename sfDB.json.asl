{
  "Comment": "A description of my state machine",
  "StartAt": "Format input for insee call",
  "States": {
    "404": {
      "Type": "Fail",
      "Error": "404",
      "Cause": "Company not found"
    },
    "500": {
      "Type": "Fail",
      "Error": "Erreur serveur"
    },
    "Format input for insee call": {
      "Type": "Pass",
      "Next": "GetItem",
      "Parameters": {
        "data": {
          "input": {
            "q.$": "States.Format('denominationUniteLegale:\"{}\"', $.data.input.name)",
            "champs": "denominationUniteLegale",
            "nombre": 1,
            "name.$": "$.data.input.name",
            "devnumber.$": "$.data.input.devnumber"
          }
        }
      }
    },
    "GetItem": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:getItem",
      "Parameters": {
        "TableName": "Company-2022-11-30",
        "Key": {
          "companyName": {
            "S.$": "$.data.input.name"
          }
        },
        "ProjectionExpression": "companyName, devnumber"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "BackoffRate": 1,
          "IntervalSeconds": 1,
          "MaxAttempts": 2
        }
      ],
      "Next": "Present in DB ?",
      "Catch": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "Next": "searchCompanyThirdParty"
        }
      ],
      "ResultPath": "$.lambdaresult"
    },
    "Present in DB ?": {
      "Type": "Choice",
      "Choices": [
        {
          "Or": [
            {
              "Not": {
                "Variable": "$.lambdaresult.Item.companyName",
                "IsPresent": true
              }
            },
            {
              "Not": {
                "Variable": "$.lambdaresult.Item",
                "IsPresent": true
              }
            }
          ],
          "Next": "searchCompanyThirdParty"
        },
        {
          "And": [
            {
              "Variable": "$.lambdaresult.Item",
              "IsPresent": true
            },
            {
              "Variable": "$.lambdaresult.Item.companyName",
              "IsPresent": true
            }
          ],
          "Next": "Success Already un DB"
        }
      ],
      "OutputPath": "$.data.input"
    },
    "Success Already un DB": {
      "Type": "Succeed"
    },
    "searchCompanyThirdParty": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:eu-west-3:911917388922:function:checkCompanyLF"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Next": "Status code"
    },
    "Status code": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.output.statusCode",
          "NumericEquals": 404,
          "Next": "404"
        },
        {
          "Variable": "$.output.statusCode",
          "NumericGreaterThan": 500,
          "Next": "500"
        }
      ],
      "Default": "Found company from API"
    },
    "Found company from API": {
      "Type": "Succeed"
    }
  }
}